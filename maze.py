# Input: room

#You are placed ina room, and each wall has 4 doors,
# they are labled North, South, East, West.  Each door can either enter a new room with more doors, or and exit, or be blocked.



# Z = BLocked
#
# EXAMPLE
# OF
# layout
# ----------------------
# | EXIT |
# --------- Z - -------- | -------- +     ------- | ---------- Z - ------- |
# | | | |
# Z + +                     Z
# | -------  +  -------- | --------  +    ----------------- Z - ------- |
# Z
# PLAYER + +                     Z
# | -------- Z - -------- | --------- Z - -------- | ---------- Z - ------- |

##########

#CHALLENGE CODE BELOW


# Using a iterative approach to maintain the stack call stack

# Create the maze with a specified size (rows x cols)
rows, cols = 3, 3
# Find the path to the exit from the player's starting position
start_row, start_col = 2, 2


class Room:
    def __init__(self, row, col, is_exit=False):
        self.row = row
        self.col = col
        self.is_exit = is_exit
        self.visited = False
        self.neighbors = {'North': None, 'South': None, 'East': None, 'West': None}

    def set_neighbor(self, direction, room):
        self.neighbors[direction] = room

    def __repr__(self):
        return f'Room({self.row}, {self.col})'


class MazeIterative:
    def __init__(self, rows, cols):
        self.grid = [[Room(row, col) for col in range(cols)] for row in range(rows)]
        self._setup_neighbors(rows, cols)

    def _setup_neighbors(self, rows, cols):
        for row in range(rows):
            for col in range(cols):
                if row > 0:
                    self.grid[row][col].set_neighbor('North', self.grid[row - 1][col])
                if row < rows - 1:
                    self.grid[row][col].set_neighbor('South', self.grid[row + 1][col])
                if col > 0:
                    self.grid[row][col].set_neighbor('West', self.grid[row][col - 1])
                if col < cols - 1:
                    self.grid[row][col].set_neighbor('East', self.grid[row][col + 1])

    def find_exit(self, start_row, start_col):
        stack = [(self.grid[start_row][start_col], [])]
        visited = set()

        while stack:
            current_room, path = stack.pop()
            if current_room.is_exit:
                return path + [f'{current_room} is the EXIT']

            if current_room not in visited:
                visited.add(current_room)
                for direction, neighbor in current_room.neighbors.items():
                    if neighbor and neighbor not in visited:
                        new_path = path + [f'From {current_room} go {direction} to {neighbor}']
                        stack.append((neighbor, new_path))

        return ["No path to exit found"]


# Create the maze with a specified size (rows x cols)
maze = MazeIterative(rows, cols)

# Set the exit room (e.g., at (0, 0))
maze.grid[0][0].is_exit = True

# Find the path to the exit from the player's starting position
path_to_exit = maze.find_exit(start_row, start_col)

for step in path_to_exit:
    print(step)


# Using Recusion.  I tend to lean away as I've ran into call stack overflows using recursion.  But always has its place
class MazeRecursive:
    def __init__(self, rows, cols):
        self.grid = [[Room(row, col) for col in range(cols)] for row in range(rows)]
        self._setup_neighbors(rows, cols)

    def _setup_neighbors(self, rows, cols):
        for row in range(rows):
            for col in range(cols):
                if row > 0:
                    self.grid[row][col].set_neighbor('North', self.grid[row - 1][col])
                if row < rows - 1:
                    self.grid[row][col].set_neighbor('South', self.grid[row + 1][col])
                if col > 0:
                    self.grid[row][col].set_neighbor('West', self.grid[row][col - 1])
                if col < cols - 1:
                    self.grid[row][col].set_neighbor('East', self.grid[row][col + 1])

    def find_exit(self, start_row, start_col):
        success = self._find_exit_recursive(self.grid[start_row][start_col], [])
        if success:
            path = ["From " + step for step in success[::-1]]
            return path
        else:
            return ["No path to exit found"]

    def _find_exit_recursive(self, room, path):
        if room.is_exit:
            return ['EXIT']
        if room.visited:
            return None

        room.visited = True

        for direction, neighbor in room.neighbors.items():
            if neighbor:
                result = self._find_exit_recursive(neighbor, path)
                if result:
                    direction_step = f'{room} go {direction} to {neighbor}'
                    return result + [direction_step]

        return None


maze = MazeRecursive(rows, cols)

# Set the exit room
maze.grid[0][0].is_exit = True

path_to_exit = maze.find_exit(start_row, start_col)

for step in path_to_exit:
    print(step)
