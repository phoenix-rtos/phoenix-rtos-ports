#!/bin/sh

root_dir="$(realpath $(dirname "$0"))"
out_dir="${root_dir}/out/phoenix-rtos"
mkdir -p "${out_dir}"

while IFS= read -r file; do
	test_file="${file%.c}"
	out_test_path="${out_dir}/${test_file}.out"
	echo "-- ${test_file}: --"
	(
		("${root_dir}/misc/run.sh" "${test_file}" "${out_test_path}") &
		cmd_pid=$!

		# watchdog
		(
			sleep 10
			kill -KILL "$cmd_pid" 2>/dev/null && echo "timeout" >>"${out_test_path}"
		) &
		watcher_pid=$!

		# wait for the command
		wait "$cmd_pid"
		cmd_rc=$?

		# if command finished, stop the watcher
		kill "$watcher_pid" 2>/dev/null

		exit $cmd_rc
	)
	cat "${out_test_path}"
done <"${root_dir}/tests.list"
