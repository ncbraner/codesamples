<?php
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

#CHALLENGE CODE BELOW
##########



//set player start and maze size
// Maze Size
$rows = 3;
$cols = 3;

// Player Start
$start_row = 2;
$start_col = 2;




trait SharedFunctions
{
    public static function getRoomKey($row, $col): string
    {
        return $row . ',' . $col;
    }

    public function setExit($row, $col): void
    {
        if ($row >= 0 && $row < count($this->grid) && $col >= 0 && $col < count($this->grid[$row])) {
            $this->grid[$row][$col]->is_exit = true;
        }
    }

    private function setupNeighbors($rows, $cols): void
    {
        for ($row = 0; $row < $rows; $row++) {
            for ($col = 0; $col < $cols; $col++) {
                if ($row > 0) {
                    $this->grid[$row][$col]->setNeighbor('North', $this->grid[$row - 1][$col]);
                }
                if ($row < $rows - 1) {
                    $this->grid[$row][$col]->setNeighbor('South', $this->grid[$row + 1][$col]);
                }
                if ($col > 0) {
                    $this->grid[$row][$col]->setNeighbor('West', $this->grid[$row][$col - 1]);
                }
                if ($col < $cols - 1) {
                    $this->grid[$row][$col]->setNeighbor('East', $this->grid[$row][$col + 1]);
                }
            }
        }
    }
}


class Room
{
    public $is_exit;
    public $visited;
    public $neighbors;
    public $row;
    public $col;

    public function __construct($row, $col, $is_exit = false)
    {
        $this->row = $row;
        $this->col = $col;
        $this->is_exit = $is_exit;
        $this->visited = false;
        $this->neighbors = ['North' => null, 'South' => null, 'East' => null, 'West' => null];
    }

    public function setNeighbor($direction, $room)
    {
        $this->neighbors[$direction] = $room;
    }

    public function __toString()
    {
        return "Room({$this->row}, {$this->col})";
    }
}

class MazeIterative
{
    use SharedFunctions;

    private $grid;

    public function __construct($rows, $cols)
    {
        $this->grid = array();
        for ($row = 0; $row < $rows; $row++) {
            $this->grid[$row] = array();
            for ($col = 0; $col < $cols; $col++) {
                $this->grid[$row][$col] = new Room($row, $col);
            }
        }
        $this->setupNeighbors($rows, $cols);
    }

    public function findExit($start_row, $start_col)
    {
        $stack = [array(self::getRoomKey($start_row, $start_col), array())];
        $visited = array();

        while (!empty($stack)) {
            list($current_key, $path) = array_pop($stack);
            list($row, $col) = explode(',', $current_key);
            $current_room = $this->grid[$row][$col];

            if ($current_room->is_exit) {
                array_push($path, "{$current_room} is the EXIT");
                return $path;
            }

            if (!in_array($current_key, $visited)) {
                array_push($visited, $current_key);
                foreach ($current_room->neighbors as $direction => $neighbor) {
                    if ($neighbor !== null && !in_array(self::getRoomKey($neighbor->row, $neighbor->col), $visited)) {
                        $new_path = $path;
                        array_push($new_path, "From {$current_room} go {$direction} to {$neighbor}");
                        array_push($stack, array(self::getRoomKey($neighbor->row, $neighbor->col), $new_path));
                    }
                }
            }
        }

        return ["No path to exit found"];
    }
}


$maze = new MazeIterative($rows, $cols);
$maze->setExit(0, 0);
$path_to_exit = $maze->findExit($start_row, $start_col);

echo "Iterative approach" . "\n";

foreach ($path_to_exit as $step) {
    echo $step . "\n";
}


class MazeRecursive
{
    use SharedFunctions;

    private $grid;
    private $visited;

    public function __construct($rows, $cols)
    {
        $this->grid = array();
        for ($row = 0; $row < $rows; $row++) {
            $this->grid[$row] = array();
            for ($col = 0; $col < $cols; $col++) {
                $this->grid[$row][$col] = new Room($row, $col);
            }
        }
        $this->setupNeighbors($rows, $cols);
        $this->visited = array();
    }


    public function findExit($start_row, $start_col)
    {
        $this->visited = array();
        $success = $this->findExitRecursive($this->grid[$start_row][$start_col]);
        if ($success) {
            return array_map(function ($step) {
                return "From " . $step;
            }, array_reverse($success));
        } else {
            return ["No path to exit found"];
        }
    }

    private function findExitRecursive($room)
    {
        $key = self::getRoomKey($room->row, $room->col);
        if ($room->is_exit) {
            return ['EXIT'];
        }
        if (in_array($key, $this->visited)) {
            return null;
        }

        $this->visited[] = $key;

        foreach ($room->neighbors as $direction => $neighbor) {
            if ($neighbor) {
                $result = $this->findExitRecursive($neighbor);
                if ($result) {
                    $direction_step = "{$room} go {$direction} to {$neighbor}";
                    $result[] = $direction_step;
                    return $result;
                }
            }
        }

        return null;
    }
}

$maze = new MazeRecursive($rows, $cols);
$maze->setExit(0, 0);
$path_to_exit = $maze->findExit($start_row, $start_col);

echo "Recursive Path" . "\n";
foreach ($path_to_exit as $step) {
    echo $step . "\n";
}
