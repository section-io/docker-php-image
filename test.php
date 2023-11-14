<?php
// this script calculates Pi as a way to test php performance

$start_time = hrtime(TRUE);

$maxRequires = 70000;
for ($times=0; $times<$maxRequires; $times++){
  require "./requireme.php";
}

$end_time = hrtime(TRUE);

$totaltime = ($end_time - $start_time)/1e+6;
echo "total time is $totaltime ms\n";
