extends Node

# Autoload: TaskAllocationManager
# Controls indirect slider-based task distribution, enforces 100% sum, and coordinates worker role transitions.

signal task_percentages_updated(percentages: Dictionary)
signal job_assignments_changed(current_counts: Dictionary, target_counts: Dictionary)

var target_percentages: Dictionary = {
	Enums.JobType.FORAGE: 0.25,
	Enums.JobType.DIG: 0.25,
	Enums.JobType.NURSE: 0.25,
	Enums.JobType.DEFEND: 0.25
}

var current_job_counts: Dictionary = {
	Enums.JobType.FORAGE: 0,
	Enums.JobType.DIG: 0,
	Enums.JobType.NURSE: 0,
	Enums.JobType.DEFEND: 0
}

var target_job_counts: Dictionary = {
	Enums.JobType.FORAGE: 0,
	Enums.JobType.DIG: 0,
	Enums.JobType.NURSE: 0,
	Enums.JobType.DEFEND: 0
}

func _ready() -> void:
	pass

func set_task_percentage(job: Enums.JobType, new_value: float) -> void:
	new_value = clampf(new_value, 0.0, 1.0)
	var old_value: float = target_percentages.get(job, 0.25)
	target_percentages[job] = new_value

	var other_jobs: Array[Enums.JobType] = [
		Enums.JobType.FORAGE,
		Enums.JobType.DIG,
		Enums.JobType.NURSE,
		Enums.JobType.DEFEND
	]
	other_jobs.erase(job)

	var remaining_needed: float = 1.0 - new_value
	var other_sum: float = 0.0
	for oj in other_jobs:
		other_sum += target_percentages[oj]

	if other_sum > 0.0001:
		for oj in other_jobs:
			target_percentages[oj] = (target_percentages[oj] / other_sum) * remaining_needed
	else:
		var split_share: float = remaining_needed / float(other_jobs.size())
		for oj in other_jobs:
			target_percentages[oj] = split_share

	task_percentages_updated.emit(target_percentages)

func recalculate_job_targets(total_ants: int) -> void:
	var allocated: int = 0
	var jobs: Array[Enums.JobType] = [
		Enums.JobType.FORAGE,
		Enums.JobType.DIG,
		Enums.JobType.NURSE,
		Enums.JobType.DEFEND
	]

	for j in jobs:
		var count: int = int(round(float(total_ants) * target_percentages.get(j, 0.25)))
		target_job_counts[j] = count
		allocated += count

	# Correct any rounding drift to strictly match total_ants
	var diff: int = total_ants - allocated
	if diff != 0:
		target_job_counts[Enums.JobType.FORAGE] += diff

	job_assignments_changed.emit(current_job_counts, target_job_counts)

func request_job_for_ant(ant: Node) -> Enums.JobType:
	var highest_deficit: int = -9999
	var selected_job: Enums.JobType = Enums.JobType.FORAGE

	var jobs: Array[Enums.JobType] = [
		Enums.JobType.FORAGE,
		Enums.JobType.DIG,
		Enums.JobType.NURSE,
		Enums.JobType.DEFEND
	]

	for j in jobs:
		var deficit: int = target_job_counts.get(j, 0) - current_job_counts.get(j, 0)
		if deficit > highest_deficit:
			highest_deficit = deficit
			selected_job = j

	return selected_job

func register_ant(job: Enums.JobType) -> void:
	current_job_counts[job] = current_job_counts.get(job, 0) + 1
	job_assignments_changed.emit(current_job_counts, target_job_counts)

func unregister_ant(job: Enums.JobType) -> void:
	current_job_counts[job] = maxi(0, current_job_counts.get(job, 0) - 1)
	job_assignments_changed.emit(current_job_counts, target_job_counts)
