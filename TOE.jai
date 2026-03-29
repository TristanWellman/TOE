/*Copyright (c) 2026 Tristan Wellman*/

/*Suppose that you wanted to copy a 500-page document. You want a perfect
copy, so you buy a new ream of paper, and copy the document one page at
a time, making sure each page is perfect. What do you do if you find a page
with a smudge? If you have more intelligence than a bowling ball, you
recopy the page and continue. If you are Unix, you give up completely, buy
a new ream of paper, and start over.*/

#import "Basic";
#import "File";
#import "POSIX";
#import "Math";

calloc :: (num: u32, size: u32) -> *void #foreign;
atoi :: (str: *u8) -> s32 #foreign;

_context: *#Context = null;

#program_export
initContext :: (argc: s32, argv: **u8) -> *#Context #c_call {
	if !_context _context = __jai_runtime_init(argc, argv);
	return _context;
}

MAX_COLUMNS :: 80;
MAX_ROWS :: 24;
TOTAL_HEADER_SPACE :: 2;

/*General Escape Codes*/
ECLEAR_SCREEN :: "\e[2J";
EHIDE_CURSOR :: "\e[?25l";
ESHOW_CURSOR :: "\e[?25h";
ERESET_COLORS :: "\e[0m";
EFONT_BOLD :: "\e[1m";
EFONT_FAINT :: "\e[2m";
EFONT_RESET_MODES :: "\e[22m";

/*Color Codes*/
BACKGROUND_COLOR :: 0;
BACKGROUND_HEADER_COLOR :: 8;
FOREGROUND_COLOR :: 254;

ARGSIZE :: 2;

/*User Commands*/
USER_INPUT_MODE :: "i";
USER_COMMAND_MODE :: "\e";
USER_MOVE_DOWN :: "d";
USER_MOVE_UP :: "u";
USER_QUIT_TOE :: "q";
USER_SAVE_FILE :: "s";
USER_LEFT :: "D";
USER_RIGHT :: "C";
USER_UP :: "A";
USER_DOWN :: "B";
USER_NEXT_LINE :: "\n";

UserMode :: enum u32 {
	COMMAND :: 0;
	INPUT :: 1;
}

UserData :: struct {
	cursorPos: Vector2s32 = .{0, 0};
	userInCursorPos: Vector2s32 = .{0, 0};	
}

FileData :: struct {
	fileName: string;
	newFile: u8;
	lines: [..]string;
	position: u32;
}

Vector2s32 :: struct {
	x, y: s32;
}

fileData: *FileData = null;
userData: UserData;

getInputDynChar :: () -> s32 {
	res: s32 = 0;
	system("/bin/stty raw");
	res = getchar();
	system("/bin/stty cooked");
	return res;
}

hideCursor :: () {
	printf("%s", EHIDE_CURSOR);
}

showCursor :: () {
	printf("%s", ESHOW_CURSOR);
}

resetScreen :: () {
	printf("%s", ECLEAR_SCREEN);
	userData.cursorPos.x = 0;
	userData.cursorPos.y = 0;
}

clearScreen :: () {
	moveCursorUp(cast(u32)MAX_ROWS-cast(u32)userData.cursorPos.y);
	resetColors();
	for x: 0..MAX_ROWS-1 {
		for y: 0..MAX_COLUMNS-1 {
			printf(" ");
		}
		printf("\n");
	}
	userData.cursorPos.x = 0;
	userData.cursorPos.y = 0;
}

moveCursorUp :: (count: u32) {printf("\e[%dA", count);}
moveCursorDown :: (count: s32) {printf("\e[%dB", count);}
moveCursorRight :: (count: u32) {printf("\e[%dC", count);}
moveCursorLeft :: (count: u32) {printf("\e[%dD", count);}
moveCursorToInputPosition :: () {
	moveCursorUp(MAX_ROWS-1-cast(u32)userData.userInCursorPos.y);
	if userData.cursorPos.x > userData.userInCursorPos.x {
		moveCursorLeft(cast(u32)userData.cursorPos.x-cast(u32)userData.userInCursorPos.x);
	} else {
		moveCursorRight(cast(u32)userData.userInCursorPos.x-cast(u32)userData.cursorPos.x);
	}
}
moveCursorToBottomInputPosition :: () {
	moveCursorDown(MAX_ROWS-1-userData.userInCursorPos.y);
}

setBackgroundColor :: (color: s32) {printf("\e[48;5;%dm", color);}
setForegroundColor :: (color: s32) {printf("\e[38;5;%dm", color);}
resetColors :: () {printf("%s", ERESET_COLORS);}

setFontBold :: () {printf("%s", EFONT_BOLD);}
setFontFaint :: () {printf("%s", EFONT_FAINT);}
resetFontModes :: () {printf("%s", EFONT_RESET_MODES);}

clearNewLineData :: (line: *string) {
	for i: 0..MAX_COLUMNS-1 line.data[i] = " ";
	line.data[MAX_COLUMNS] = "\0";
}

drawHeader :: () {
	setBackgroundColor(BACKGROUND_HEADER_COLOR);
	setFontBold();
	printf("  ");
	for i: 0..MAX_COLUMNS-1 {
		if !(i%10) printf("%d", i/10);
		else if !(i%5) printf("+");
		else printf(".");
	}
	printf("\n");
	resetFontModes();
}

getModeString :: (mode: UserMode) -> string {
	if mode == {
		case .COMMAND; return "COMMAND";
		case .INPUT; return "INPUT";
	}
	return "INVALID MODE!!!";
}

drawCommandFooter :: (mode: UserMode) {
	setBackgroundColor(BACKGROUND_HEADER_COLOR);
	setFontBold();
	curMode := getModeString(mode);
	len := curMode.count+fileData.fileName.count+(fileData.position%10)+7;
	userData.cursorPos.x = xx len;
	printf("<%s> %s:%d >> ", curMode.data, fileData.fileName.data, fileData.position);
	resetFontModes();
}

drawFileData :: () {
	assert(fileData!=null);
	setBackgroundColor(BACKGROUND_COLOR);
	drawLimit := fileData.lines.count;
	for i: fileData.position..drawLimit-1 {
		if i-fileData.position > MAX_ROWS-TOTAL_HEADER_SPACE break;
		setBackgroundColor(BACKGROUND_HEADER_COLOR);
		setFontFaint();
		printf("%d ", i);
		resetFontModes();
		setBackgroundColor(BACKGROUND_COLOR);
		printf("%s\n", fileData.lines[i].data);
		userData.cursorPos.y = userData.cursorPos.y+1;
	}
	if fileData.lines.count < MAX_ROWS-TOTAL_HEADER_SPACE {
		for i: 0..MAX_ROWS-TOTAL_HEADER_SPACE-fileData.lines.count {
			printf("\n");
			userData.cursorPos.y = userData.cursorPos.y+1;
		}
	}
}

drawScreen :: (mode: UserMode) {
	hideCursor();
	clearScreen();
	drawHeader();
	drawFileData();
	if mode == .COMMAND moveCursorDown(MAX_ROWS-1-cast(s32)userData.cursorPos.y);
	drawCommandFooter(mode);
	showCursor();
	resetColors();
}

moveUserFile :: (count: s32) {
	if cast(s32)fileData.position+count < 0 {fileData.position = 0;return;}
	if cast(s32)fileData.position+count > fileData.lines.count {
		fileData.position = xx fileData.lines.count;
		return;
	}
	fileData.position = cast(u32)(cast(s32)fileData.position+count);
}

runTOELoop :: () {
	currentMode: UserMode = .COMMAND;
	someCount: s32 = 0;
	input: [128]u8;
	resetScreen();
	while true {
		if input[0] == USER_COMMAND_MODE currentMode = .COMMAND;
		
		if currentMode == .COMMAND {
			if input[0] == USER_INPUT_MODE {
				currentMode = .INPUT;
				userData.userInCursorPos = .{0, 0};
			} else if input[0] == USER_MOVE_UP moveUserFile(xx -someCount);
			else if input[0] == USER_MOVE_DOWN moveUserFile(xx someCount);
			else if input[0] == USER_SAVE_FILE {saveFileData();break;}
			else if input[0] == USER_QUIT_TOE break;
		}

		drawScreen(currentMode);
		
		if currentMode == .COMMAND {
			scanf("%128s", input.data);
			someCount = atoi(input.data+1);
		} else if currentMode == .INPUT {
			moveCursorToInputPosition();
			input[0] = xx getInputDynChar();
			if input[0] >= 20 && input[0] <= 126 {
				line := *fileData.lines[fileData.position];
				if userData.userInCursorPos.x < MAX_COLUMNS {
					data: *u8;
					data = cast(*u8)calloc(MAX_COLUMNS+1, size_of(u8));
					for i: 0..userData.userInCursorPos.x-1 data[i] = line.data[i];
					data[userData.userInCursorPos.x] = input[0];
					userData.userInCursorPos.x = userData.userInCursorPos.x+1;
					for i: userData.userInCursorPos.x..MAX_COLUMNS-1 data[i] = line.data[i];
					free(line.data);
					line.data = data;
					line.count = line.count+1;
				}
			} else if input[0]==13 {
				line: string;
				line.count = 0;
				line.data = cast(*u8)calloc(MAX_COLUMNS+1, size_of(u8));
				clearNewLineData(*line);
				fileData.position = fileData.position+1;
				array_insert_at(*fileData.lines, line, fileData.position);
				userData.userInCursorPos = .{0, 0};
			}
			moveCursorToBottomInputPosition();
			someCount = 0;
		}
	}
}

saveFileData :: () {
	file, s := file_open(fileData.fileName, for_writing=true, keep_existing_content=false);
	if !s return;
	defer file_close(*file);
	for i: 0..fileData.lines.count-1 {
		fs := file_write(*file, fileData.lines[i].data, fileData.lines[i].count);
		if !fs return;
		ret: *u8 = "\n";
		fs = file_write(*file, ret, 1);
		if !fs return;
	}
}

initFileData :: (fileData: *FileData) {
	fileData.position = 0;
	data, s := read_entire_file(fileData.fileName);
	line: string;
	line.count = 0;
	line.data = cast(*u8)calloc(MAX_COLUMNS+1, size_of(u8));
	clearNewLineData(*line);
	if !s {
		fileData.newFile = 1;
		array_add(*fileData.lines, line);
	} else {
		fileData.newFile = 0;
		for i: 0..data.count-1 {
			if data.data[i] == "\0" break;
			if data.data[i] == "\n" {
				array_add(*fileData.lines, line);
				line.count = 0;
				line.data = cast(*u8)calloc(MAX_COLUMNS+1, size_of(u8));
				clearNewLineData(*line);
			} else {
				line.data[line.count] = data.data[i];
				line.count = line.count+1;
			}
		}
	}
}

/*The main exporting is so we can compile the bitcode to work on like ppc64.*/
#program_export "main"
expMain :: (argc: s32, argv: **u8) -> s32 #c_call {
	initContext(argc, argv);
	push_context _context {
		args := get_command_line_arguments();
		//assert(args.count==ARGSIZE);
		if args.count != ARGSIZE return 1;
		
		fileData = cast(*FileData)calloc(1, size_of(FileData));
		defer free(fileData);
		fileData.fileName = args[1];

		initFileData(fileData);
		runTOELoop();
		return 0;
	}
}

//#program_export "jaiMain"
main :: () {}
