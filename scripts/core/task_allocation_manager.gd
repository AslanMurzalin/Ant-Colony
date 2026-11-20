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

var locked_sliders: Dictionary = {
	Enums.JobType.FORAGE: false,
	Enums.JobType.DIG: false,
	Enums.JobType.NURSE: false,
	Enums.JobType.DEFEND: false
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

func lock_slider(job: Enums.JobType, is_locked: bool) -> void:
	locked_sliders[job] = is_locked

func is_slider_locked(job: Enums.JobType) -> bool:
	return locked_sliders.get(job, false)

func get_job_percentage(job: Enums.JobType) -> float:
	return target_percentages.get(job, 0.0)

func get_job_target_count(job: Enums.JobType) -> int:
	return target_job_counts.get(job, 0)

func get_job_current_count(job: Enums.JobType) -> int:
	return current_job_counts.get(job, 0)

func set_task_percentage(job: Enums.JobType, new_value: float) -> void:
	new_value = clampf(new_value, 0.0, 1.0)
	
	var all_jobs: Array[Enums.JobType] = [
		Enums.JobType.FORAGE,
		Enums.JobType.DIG,
		Enums.JobType.NURSE,
		Enums.JobType.DEFEND
	]

	# Find unlocked other jobs
	var unlocked_other_jobs: Array[Enums.JobType] = []
	var locked_sum: float = 0.0

	for j in all_jobs:
		if j == job:
			continue
		if locked_sliders.get(j, false):
			locked_sum += target_percentages[j]
		else:
			unlocked_other_jobs.append(j)

	# Cap new_value so locked sliders aren't violated
	var max_allowed_for_job: float = 1.0 - locked_sum
	new_value = clampf(new_value, 0.0, max_allowed_for_job)
	target_percentages[job] = new_value

	var remaining_needed: float = 1.0 - new_value - locked_sum
	remaining_needed = maxf(0.0, remaining_needed)

	if unlocked_other_jobs.size() > 0:
		var unlocked_sum: float = 0.0
		for oj in unlocked_other_jobs:
			unlocked_sum += target_percentages[oj]

		if unlocked_sum > 0.0001:
			for oj in unlocked_other_jobs:
				target_percentages[oj] = (target_percentages[oj] / unlocked_sum) * remaining_needed
		else:
			var split_share: float = remaining_needed / float(unlocked_other_jobs.size())
			for oj in unlocked_other_jobs:
				target_percentages[oj] = split_share

	# Final normalization pass to prevent floating point drift beyond 1.0
	var final_sum: float = 0.0
	for j in all_jobs:
		final_sum += target_percentages[j]
	if final_sum > 0.00001:
		for j in all_jobs:
			target_percentages[j] = target_percentages[j] / final_sum

	task_percentages_updated.emit(target_percentages)

func recalculate_job_targets(total_ants: int) -> void:
	if total_ants <= 0:
		for j in target_job_counts.keys():
			target_job_counts[j] = 0
		job_assignments_changed.emit(current_job_counts, target_job_counts)
		return

	var jobs: Array[Enums.JobType] = [
		Enums.JobType.FORAGE,
		Enums.JobType.DIG,
		Enums.JobType.NURSE,
		Enums.JobType.DEFEND
	]

	# Largest Remainder Method (Hamilton method)
	var int_parts: Dictionary = {}
	var remainders: Array[Dictionary] = []
	var allocated: int = 0

	for j in jobs:
		var exact: float = float(total_ants) * target_percentages.get(j, 0.25)
		var int_val: int = int(floor(exact))
		int_parts[j] = int_val
		allocated += int_val
		remainders.append({
			"job": j,
			"rem": exact - float(int_val)
		})

	# Distribute remaining ants to the jobs with largest fractional remainder
	remainders.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["rem"] > b["rem"]
	)

	var seats_left: int = total_ants - allocated
	for i in range(seats_left):
		var target_j: Enums.JobType = remainders[i % remainders.size()]["job"]
		int_parts[target_j] += 1

	for j in jobs:
		target_job_counts[j] = int_parts[j]

	job_assignments_changed.emit(current_job_counts, target_job_counts)

func request_job_for_ant(ant: AntController) -> Enums.JobType:
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
