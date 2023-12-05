<?php
function checkTicTacToeWinner($board) {
    $linesToCheck = [];

    // Add rows and columns to the lines to check
    for ($i = 0; $i < 3; $i++) {
        $linesToCheck[] = [$board[$i][0], $board[$i][1], $board[$i][2]]; // Rows
        $linesToCheck[] = [$board[0][$i], $board[1][$i], $board[2][$i]]; // Columns
    }

    // Add diagonals to the lines to check
    $linesToCheck[] = [$board[0][0], $board[1][1], $board[2][2]]; // Diagonal from top-left to bottom-right
    $linesToCheck[] = [$board[0][2], $board[1][1], $board[2][0]]; // Diagonal from top-right to bottom-left

    // Check each line for a winner
    foreach ($linesToCheck as $line) {
        if ($line[0] === $line[1] && $line[1] === $line[2]) {
            if ($line[0] === 'X') {
                return 'X';
            } elseif ($line[0] === 'O') {
                return 'O';
            }
        }
    }

    return 'No winner';
}

// Board 1
$board1 = [
    ['X', 'O', 'X'],
    ['O', 'X', 'O'],
    ['O', 'X', 'X']
];
echo "Board 1 Winner: " . checkTicTacToeWinner($board1) . "\n";

// Board 2
$board2 = [
    ['X', 'X', 'X'],
    ['O', 'O', ' '],
    [' ', ' ', ' ']
];
echo "Board 2 Winner: " . checkTicTacToeWinner($board2) . "\n";

// Board 3
$board3 = [
    ['O', 'X', 'O'],
    ['X', 'O', 'X'],
    ['X', 'O', 'O']
];
echo "Board 3 Winner: " . checkTicTacToeWinner($board3) . "\n";

// Board 4 no winner
$board4 = [
    ['O', 'X', 'O'],
    ['X', 'O', 'X'],
    ['X', 'O', 'X']
];
echo "Board 4 Winner: " . checkTicTacToeWinner($board4) . "\n";