<?php
$limit = 3;
function scale($value, $factor) {
    $total = $value * $factor;
    foreach ([1, 2] as $i) { $total += $i; }
    return $total;
}
function twice($value) {
    $total = $value * 2; // $total in a comment
    return $total;
}
echo "total limit " . scale($limit, 2);
