<?php
require_once __DIR__ . '/config.php';
$_SESSION = [];
session_destroy();
echo json_encode(['success' => true]);
