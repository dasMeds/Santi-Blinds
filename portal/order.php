<?php
// POST { quotation_id, address }   -> order from one of the customer's own Active quotations
// POST { items: [...], address }   -> order placed directly from the design (no quotation)
// Either way the prices are checked/computed on the server and stock is reduced in one transaction.
require_once __DIR__ . '/config.php';
requireMethod('POST');
$customerId = requireCustomer();
$b   = requestBody();
$pdo = getDB();

$qid      = (int)($b['quotation_id'] ?? 0);
$useQuote = $qid > 0;
$address  = str($b, 'address', 255);
$errors   = [];
if ($address === '') $errors[] = 'Installation / delivery address is required.';
if ($errors) respond(['success' => false, 'errors' => $errors], 422);

// Basic spam throttle: 5 orders per 10 minutes per browser session.
if (recentCount('order_times') >= 5) {
    respond(['success' => false, 'message' => 'Too many orders in a short time. Please wait a few minutes.'], 429);
}

// Direct order: price the items now, exactly as a quotation would.
$direct = null;
if (!$useQuote) {
    $direct = validateItems($pdo, $b['items'] ?? []);
    if ($direct['errors']) respond(['success' => false, 'errors' => $direct['errors']], 422);
}

$pdo->beginTransaction();
try {
    if ($useQuote) {
        // 0) Lock the quotation so it can only ever be turned into one order.
        $q = loadQuotation($pdo, $qid, $customerId, true);
        if (!$q) { $pdo->rollBack(); respond(['success' => false, 'message' => 'Quotation not found.'], 404); }
        if ($q['status'] === 'Ordered') { $pdo->rollBack(); respond(['success' => false, 'message' => 'An order has already been placed from this quotation.'], 409); }
        if ($q['status'] === 'Expired') { $pdo->rollBack(); respond(['success' => false, 'message' => 'This quotation has expired. Please design your blinds again to get a new one.'], 409); }

        $lines       = $q['items'];
        $total       = $q['total_amount'];
        $quotationId = $qid;
        $quoteRef    = $q['reference'];
    } else {
        $lines       = $direct['rows'];
        $total       = $direct['total'];
        $quotationId = null;
        $quoteRef    = null;
    }

    // Total quantity needed per product (the same product may appear in several items).
    $need = [];
    foreach ($lines as $r) {
        $need[$r['product_id']] = ($need[$r['product_id']] ?? 0) + $r['quantity'];
    }
    ksort($need); // fixed order avoids deadlocks between simultaneous orders

    // 1) Take the stock. The "stock_qty >= :need" guard makes it impossible to go negative.
    $take = $pdo->prepare("UPDATE product SET stock_qty = stock_qty - :q WHERE product_id = :p AND stock_qty >= :need");
    foreach ($need as $pid => $qty) {
        $take->execute([':q' => $qty, ':p' => $pid, ':need' => $qty]);
        if ($take->rowCount() === 0) {
            $pdo->rollBack();
            $info = $pdo->prepare("SELECT name, stock_qty FROM product WHERE product_id = :p");
            $info->execute([':p' => $pid]);
            $p    = $info->fetch();
            $name = $p ? $p['name'] : 'This product';
            $left = $p ? max(0, (int)$p['stock_qty']) : 0;
            respond(['success' => false, 'message' => $left > 0
                ? "Sorry, only {$left} of {$name} left in stock. Please lower the quantity."
                : "Sorry, {$name} is out of stock right now."], 409);
        }
    }

    // 2) Keep the delivery address on the customer record.
    $pdo->prepare("UPDATE customer SET address = :a WHERE customer_id = :c")
        ->execute([':a' => $address, ':c' => $customerId]);

    // 3) Save the order. Items of one order share an order_id.
    $orderId = (int)$pdo->query("SELECT COALESCE(MAX(order_id), 0) + 1 FROM orders FOR UPDATE")->fetchColumn();

    $ins = $pdo->prepare(
        "INSERT INTO orders (order_id, customer_id, quotation_id, product_id, material_id, color_id,
                             width_cm, height_cm, quantity, unit_price, total_amount, status)
         VALUES (:o, :c, :qt, :p, :m, :cl, :w, :h, :q, :u, :t, 'Pending')"
    );
    foreach ($lines as $r) {
        $ins->execute([':o' => $orderId, ':c' => $customerId, ':qt' => $quotationId, ':p' => $r['product_id'],
                       ':m' => $r['material_id'], ':cl' => $r['color_id'],
                       ':w' => $r['width_cm'], ':h' => $r['height_cm'], ':q' => $r['quantity'],
                       ':u' => $r['unit_price'], ':t' => $r['total_amount']]);
    }

    // 4) If it came from a quotation, that quotation is now used up.
    if ($useQuote) {
        $pdo->prepare("UPDATE quotation SET status = 'Ordered' WHERE quotation_id = :id")->execute([':id' => $qid]);
    }

    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    throw $e;
}

recordHit('order_times');
respond([
    'success' => true,
    'order'   => ['id' => $orderId, 'reference' => sprintf('SB-%05d', $orderId), 'amount' => $total,
                  'items' => count($lines), 'quotation' => $quoteRef],
    'message' => 'Thank you! Your order has been received.',
]);
