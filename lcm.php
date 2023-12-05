<?php
//Challenge
#Given an array of integers, create a function that will find the smallest positive integer that is evenly divisible by
# all the members of the array. In other words, find the least common multiple (LCM).

// Function to calculate the Greatest Common Divisor (GCD) using the Euclidean algorithm.
function gcd($a, $b) {
while ($b != 0) {
$t = $b;
$b = $a % $b; // Modulus operator finds the remainder of division of $a by $b.
$a = $t; // Swap the values of $a and $b for the next iteration.
}
return $a; // When $b becomes 0, $a contains the GCD.
}

// Function to calculate the Least Common Multiple (LCM) using the formula LCM(a, b) = |a * b| / GCD(a, b).
function findLCM($a, $b) {
return abs($a * $b) / gcd($a, $b); // The LCM is the absolute product of $a and $b divided by their GCD.
}

// Function to find the LCM of an array of numbers.
function lcm($nums) {
$result = $nums[0]; // Start with the first element in the array.
for ($i = 1; $i < count($nums); $i++) {
$result = findLCM($result, $nums[$i]); // Update $result with the LCM of $result and the next element.
}
return $result; // Return the final LCM result after iterating through the array.
}

// Example Usage
$nums = [2, 3, 4, 5, 6];
echo "LCM of the array is: " . lcm($nums);
