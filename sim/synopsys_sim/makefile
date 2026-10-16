.DEFAULT_GOAL := usage

VCS_CMD = vcs -full64 -sverilog +v2k \
	-debug_access+all \
	-debug_acc+pp+dmptf \
	-ntb_opts uvm-1.1 \
	+memcbk \
	+vcs+fsdbon+all \
	-override_timescale=1ns/1ps \
	-cm line+cond+tgl+fsm+branch

ifndef test
test = i3c_base_test
endif

ifndef seed
seed = 1
endif

ifndef uvm_verbosity
uvm_verbosity = UVM_FULL
endif

ifndef i3c_type
i3c_type = STANDARD_I3C
endif

ifndef test_folder
test_folder = $(test)
endif

ifndef testlist_name
testlist_name = i3c_regression.list
endif

ifndef num_seeds
num_seeds = 10
endif

usage:
	@echo ""
	@echo "Usage:"
	@echo "  make compile"
	@echo "  make simulate test=<test_name> seed=<seed>"
	@echo "  make regression testlist_name=<list> num_seeds=<N>"
	@echo "  make merge_cov_report"
	@echo ""

all: compile simulate

compile:
	$(VCS_CMD) \
		-l i3c_compile.log \
		+plusarg_ignore \
		-f ../i3c_compile.f
	@status=$$?; \
	if [ $$status -ne 0 ]; then exit $$status; fi
	@echo "Compilation log: i3c_compile.log"

simulate:
	mkdir -p $(test_folder)
	./simv \
		+UVM_TESTNAME=$(test) \
		+UVM_VERBOSITY=$(uvm_verbosity) \
		+ntb_random_seed=$(seed) \
		+define+$(i3c_type) \
		-cm line+cond+tgl+fsm+branch \
		-cm_dir $(test_folder)/$(test)_seed$(seed).vdb \
		-l $(test_folder)/$(test).log

regression: compile
	python regression_handling.py $(testlist_name) $(num_seeds)
	$(MAKE) merge_cov_report

merge_cov_report:
	rm -rf merged_coverage.vdb merged_cov_html_report
	urg -dir *_seed*/*.vdb \
		-dbname merged_coverage \
		-report merged_cov_html_report \
		-format both
	@echo ""
	@echo "Coverage report: merged_cov_html_report/dashboard.html"
	@echo ""

compile_war_err:
	-grep "^Error" i3c_compile.log
	@echo "Compilation log: i3c_compile.log"

simulate_war_err:
	-grep "Error" $(test_folder)/$(test).log
	-grep "UVM_FATAL" $(test_folder)/$(test).log
	-grep "UVM_ERROR" $(test_folder)/$(test).log
	-grep "UVM_WARNING" $(test_folder)/$(test).log

clean_compile:
	rm -rf csrc simv simv.daidir simv.vdb *.key *.log vc_hdrs.h

clean_simulate:
	rm -rf *_test* *_seed*

clean: clean_compile clean_simulate
	rm -rf merged_coverage.vdb merged_cov_html_report
