
#Given an array of integers, create a function that will find the smallest positive integer that is evenly divisible by
# all the members of the array. In other words, find the least common multiple (LCM).
from math import gcd

def lcm(a, b):
    return abs(a*b) // gcd(a, b)

def find_lcm(nums):
    result = nums[0]
    for i in nums[1:]:
        result = lcm(result, i)
    return result

# Example Usage
nums = [2, 3, 4, 5, 6]
print("LCM of the array is:", find_lcm(nums))
