def check_tic_tac_toe_winner(board):
    lines_to_check = []

    # Add rows and columns to the lines to check
    for i in range(3):
        lines_to_check.append([board[i][0], board[i][1], board[i][2]])  # Rows
        lines_to_check.append([board[0][i], board[1][i], board[2][i]])  # Columns

    # Add diagonals to the lines to check
    lines_to_check.append([board[0][0], board[1][1], board[2][2]])  # Diagonal from top-left to bottom-right
    lines_to_check.append([board[0][2], board[1][1], board[2][0]])  # Diagonal from top-right to bottom-left

    # Check each line for a winner
    for line in lines_to_check:
        if line[0] == line[1] == line[2]:
            if line[0] == 'X':
                return 'X'
            elif line[0] == 'O':
                return 'O'

    return 'No winner'

# Board 1
board1 = [
    ['X', 'O', 'X'],
    ['O', 'X', 'O'],
    ['O', 'X', 'X']
]
print("Board 1 Winner:", check_tic_tac_toe_winner(board1))

# Board 2
board2 = [
    ['X', 'X', 'X'],
    ['O', 'O', ' '],
    [' ', ' ', ' ']
]
print("Board 2 Winner:", check_tic_tac_toe_winner(board2))

# Board 3
board3 = [
    ['O', 'X', 'O'],
    ['X', 'O', 'X'],
    ['X', 'O', 'O']
]
print("Board 3 Winner:", check_tic_tac_toe_winner(board3))

# Board 4 no winner
board4 = [
    ['O', 'X', 'O'],
    ['X', 'O', 'X'],
    ['X', 'O', 'X']
]
print("Board 4 Winner:", check_tic_tac_toe_winner(board4))
