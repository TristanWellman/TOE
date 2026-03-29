/*Copyright (c) 2026 Tristan Wellman*/

#import "Basic";
#import "Compiler";
#import "Process";

TFILE :: "TOE.jai";
TOBJ :: "TOE.o";
TBITCODE :: "TOE.bc";
TBIN :: "TOE";

compile_clang :: () {
	COMPILER := "clang";
	#if OS == .MACOS {
		COMPILER = "/opt/homebrew/opt/llvm/bin/clang";
	}

	run_command(COMPILER, "--target=ppc64", "-mabi=elfv2", "-D'__error=__errno_location'",
		"-c", "TOE.ppc64.bc", "-o", tprint("%%", TBIN, ".ppc64.o"));
}

wait_for_compiler :: () {
	while true {
		msg := compiler_wait_for_message();
		if !msg break;
		if msg.kind == .COMPLETE break;
	}
}

#run {


	w := compiler_create_workspace();
	assert(w>0);

	tOptions := get_build_options(w);
	tOptions.backend = .LLVM;
	tOptions.llvm_options.enable_split_modules = false;
	tOptions.output_executable_name = "TOE";
	tOptions.entry_point_name = "main";


	set_build_options_dc(.{do_output=false});
	set_build_options(tOptions, w);
	compiler_begin_intercept(w);
	add_build_file(TFILE, w);
	wait_for_compiler();
	compiler_end_intercept(w);
	
	/*Compile for non-native arches like ppc64*/
	w = compiler_create_workspace();
	tOptions.output_type = .OBJECT_FILE;
	tOptions.llvm_options.output_bitcode = true;
	tOptions.os_target = .LINUX;
	tOptions.cpu_target = .ARM64;
	tOptions.output_executable_name = tprint("%.ppc64", TBIN);
	set_build_options(tOptions, w);
	compiler_begin_intercept(w);
	add_build_file(TFILE, w);
	wait_for_compiler();
	compiler_end_intercept(w);

	compile_clang();
}

main :: () {}
