echo "pe_name smp" > qconf-pe-smp.txt
echo "slots $1" >> qconf-pe-smp.txt
echo "user_lists NONE" >> qconf-pe-smp.txt
echo "xuser_lists NONE" >> qconf-pe-smp.txt
echo "start_proc_args /bin/true" >> qconf-pe-smp.txt
echo "stop_proc_args /bin/true" >> qconf-pe-smp.txt
echo 'allocation_rule $pe_slots' >> qconf-pe-smp.txt
echo "control_slaves FALSE" >> qconf-pe-smp.txt
echo "job_is_first_task TRUE" >> qconf-pe-smp.txt
echo "urgency_slots min" >> qconf-pe-smp.txt
echo "accounting_summary FALSE" >> qconf-pe-smp.txt
echo "qsort_args NONE" >> qconf-pe-smp.txt
echo "pe_name mpi" > qconf-pe-mpi.txt
echo "slots 99999" >> qconf-pe-mpi.txt
echo "user_lists NONE" >> qconf-pe-mpi.txt
echo "xuser_lists NONE" >> qconf-pe-mpi.txt
echo "start_proc_args NONE" >> qconf-pe-mpi.txt
echo "stop_proc_args NONE" >> qconf-pe-mpi.txt
echo "allocation_rule \$fill_up" >> qconf-pe-mpi.txt
echo "control_slaves TRUE" >> qconf-pe-mpi.txt
echo "job_is_first_task FALSE" >> qconf-pe-mpi.txt
echo "urgency_slots min" >> qconf-pe-mpi.txt
echo "accounting_summary FALSE" >> qconf-pe-mpi.txt
echo "qsort_args NONE" >> qconf-pe-mpi.txt
