extends Resource
class_name EnemyWave
## One group of enemies that appear together. A mission has a list of these
## (the GDD wants 2 / 3 / 1 waves for the three levels). Order in the array =
## left-to-right slot order on the stage.

@export var enemies: Array[EnemyType] = []
