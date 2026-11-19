<?php
// ============================================================
//  Encrypt rows that are still plaintext (and fill the e-mail blind indexes).
//  CLI only. Safe to re-run: already-encrypted values are skipped.
//
//    php tools/encrypt_existing_data.php             encrypt everything still plaintext
//    php tools/encrypt_existing_data.php --dry-run   show what would change, write nothing
//    php tools/encrypt_existing_data.php --rotate    also re-encrypt values written with an
//                                                    older key (after generate_key.php --rotate)
//
//  Run database/migrate_encryption.sql FIRST (widens columns, adds email_bidx).
//  Take a database backup before the first run.
// ============================================================
if (PHP_SAPI !== 'cli') { http_response_code(403); exit; }
require_once __DIR__ . '/../db_config.php';

$rotate = in_array('--rotate', $argv, true);
$dry    = in_array('--dry-run', $argv, true);

// table => primary key, encrypted columns, blind-index column => source column
$spec = [
    'customers'         => ['pk' => 'id',       'enc' => ['fname', 'lname', 'email', 'phone', 'location'], 'bidx' => ['email_bidx' => 'email']],
    'customer_accounts' => ['pk' => 'id',       'enc' => ['email'],                                        'bidx' => ['email_bidx' => 'email']],
    'enquiries'         => ['pk' => 'id',       'enc' => ['fname', 'lname', 'email', 'phone', 'city', 'message']],
    'customizations'    => ['pk' => 'id',       'enc' => ['notes']],
    'orders'            => ['pk' => 'id',       'enc' => ['specifications']],
    'order_details'     => ['pk' => 'order_id', 'enc' => ['delivery_address', 'contact_no', 'notes']],
    'customer_activity' => ['pk' => 'id',       'enc' => ['email', 'details', 'ip_address'],               'bidx' => ['email_bidx' => 'email']],
];

$pdo    = getDB();
$curKid = encKeyring()['current'];
echo ($dry ? "DRY RUN - nothing will be written.\n" : '') . "Current key id: {$curKid}\n\n";

try {
    foreach ($spec as $table => $def) {
        $pk      = $def['pk'];
        $bidx    = $def['bidx'] ?? [];
        $selCols = array_merge([$pk], $def['enc'], array_keys($bidx));
        $rows    = $pdo->query('SELECT `' . implode('`,`', $selCols) . "` FROM `{$table}`")->fetchAll();

        if (!$dry) $pdo->beginTransaction();
        $changed = 0;

        foreach ($rows as $r) {
            $set   = [];
            $plain = [];

            foreach ($def['enc'] as $col) {
                $v   = $r[$col];
                $ctx = "{$table}.{$col}";
                if ($v === null || $v === '') { $plain[$col] = $v; continue; }

                if (isEncrypted($v)) {
                    $plain[$col] = decField($v, $ctx);                 // also proves the key works
                    if ($rotate && encKidOf($v) !== $curKid) $set[$col] = encField($plain[$col], $ctx);
                } else {
                    $plain[$col] = $v;
                    $set[$col]   = encField($v, $ctx);
                }
            }
            foreach ($bidx as $bcol => $src) {
                $new = blindIndex($plain[$src] ?? null);
                if ($new !== $r[$bcol]) $set[$bcol] = $new;
            }

            if (!$set) continue;
            $changed++;
            if ($dry) continue;

            $assign = implode(', ', array_map(fn($c) => "`{$c}` = :v_{$c}", array_keys($set)));
            $st = $pdo->prepare("UPDATE `{$table}` SET {$assign} WHERE `{$pk}` = :pk");
            foreach ($set as $c => $val) $st->bindValue(":v_{$c}", $val);
            $st->bindValue(':pk', $r[$pk]);
            $st->execute();
        }

        if (!$dry) $pdo->commit();
        printf("  %-18s %5d rows scanned, %5d %s\n", $table, count($rows), $changed, $dry ? 'would change' : 'updated');
    }
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    fwrite(STDERR, "\nFAILED, current table rolled back: " . $e->getMessage() . "\n");
    exit(1);
}

echo "\nDone." . ($dry ? '' : " Now set ENC_ALLOW_LEGACY_PLAINTEXT to false in db_config.php.") . "\n";
