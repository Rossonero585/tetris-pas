program tetris;
uses crt;

const
    figuresCount = 7;
    pointsCount = 4;
    filler = '#';
    pointHeight = 2;
    pointWidth = 3;
    windowHeight = 15;
    windowWidth = 10;
    sideSpace = 20;
    bottomSpace = 5;
    defaultTickMs = 500;    
    figures: array [1..figuresCount, 1..pointsCount, 0..1] of integer = 
    (
        ((0, 0), (0, 1), (0, 2), (0, 3)),
        ((0, 0), (0, 1), (0, 2), (1, 2)),
        ((0, 0), (0, 1), (1, 1), (2, 1)),
        ((0, 0), (0, 1), (1, 1), (1, 2)),
        ((0, 0), (1, 0), (1, 1), (2, 1)),
        ((0, 0), (0, 1), (1, 0), (1, 1)),
        ((0, 0), (1, 0), (1, 1), (2, 0))
    );

type
    pscreen = ^screen;
    
    screen = record
        posX: integer;
        posY: integer;
        width: integer;
        height: integer; 
    end;    

    ppoint = ^point;
    point = record
        x: integer;
        y: integer;
        next: ppoint;
    end;
    
    pfigure = ^figure;
    figure = record
        firstPoint: ppoint;
        lastPoint: ppoint;
        x: integer;
        y: integer;
    end;
    
    pmatrix = ^matrix;
    matrix = array [0..windowWidth - 1, 0..windowHeight - 1] of boolean;

    pfigurePoints = ^figurePoints;
    figurePoints = array [1..pointsCount, 0..1] of integer;
    cornerCoords = array [1..4] of integer;
    
var
    iFigure: pfigure = nil;
    nextFigure: pfigure = nil;
    mainScreen: pscreen;
    key: integer;
    tickTime: integer;
    mainMatrix: pmatrix; 
    moved: boolean = false;
    isStarted: boolean = false;
    isPaused: boolean = false;
    score: integer = 0;
    

procedure addPoint(var tempFigure: pfigure; x, y: integer);
var
    tempPoint: ppoint;
begin
    if tempFigure^.firstPoint = nil then
    begin
        new(tempFigure^.firstPoint);
        tempFigure^.firstPoint^.x := x;
        tempFigure^.firstPoint^.y := y;
        tempFigure^.firstPoint^.next := nil;
        tempFigure^.lastPoint := tempFigure^.firstPoint;
    end
    else 
    begin
        new(tempFigure^.lastPoint^.next);
        tempPoint := tempFigure^.lastPoint^.next;
        tempPoint^.x := x;
        tempPoint^.y := y;
        tempPoint^.next := nil;
        tempFigure^.lastPoint := tempPoint;
    end;
end;

procedure initFigure(var tempFigure: pfigure; figurePoints: figurePoints);
var
    i: integer;
begin
    tempFigure^.firstPoint := nil;
    tempFigure^.lastPoint := nil;

    for i := 1 to pointsCount do 
    begin
        addPoint(tempFigure, figurePoints[i, 0], figurePoints[i, 1]);
    end;
end;

procedure initRandomFigure(var tempFigure: pfigure);
var
    randomIndex: integer;
begin
    randomIndex := random(figuresCount) + 1;
    initFigure(tempFigure, figures[randomIndex]);
end;

procedure destroyFigure(var tempFigure: pfigure);
var 
    currentPoint: ppoint;
    tempPoint: ppoint;
begin
    currentPoint := tempFigure^.firstPoint;
    while currentPoint <> nil do 
    begin
        tempPoint := currentPoint^.next;
        dispose(currentPoint);
        currentPoint := tempPoint;
    end;
    dispose(tempFigure);
    tempFigure := nil;
end;

procedure printPoint(var screen: pscreen; x, y: integer; ch: char);
var 
    absX: integer;
    absY: integer;
    i: integer;
    j: integer;
begin
    absX := screen^.posX + x * pointWidth;
    absY := screen^.posY + y * pointHeight;
    for i := absX to absX + pointWidth - 1 do
    begin
        for j := absY to absY + pointHeight - 1  do
        begin
            GotoXY(i, j);
            write(ch);
        end;
    end;
end;

procedure printFigure(
    var mainScreen: pscreen;  
    var figure: pfigure; 
    ch: char
);
var 
    tempPoint: ppoint;
begin
    tempPoint := figure^.firstPoint;
    while tempPoint <> nil do
    begin
        printPoint(
            mainScreen, 
            figure^.x + tempPoint^.x, 
            figure^.y + tempPoint^.y, 
            ch
        );
        tempPoint := tempPoint^.next;
    end;
end;

procedure setPosition(var tempFigure: pfigure; x: integer; y: integer);
begin
    tempFigure^.x := x;
    tempFigure^.y := y;
end;

procedure rotateFigure(var tempFigure: pfigure; reverse: boolean);
var
    tempPoint: ppoint;
    cloneFirstPoint: ppoint;
    x: integer;
    y: integer;
    shiftX: integer = 0;
    shiftY: integer = 0;
begin
    new(cloneFirstPoint);
 
    tempPoint := tempFigure^.firstPoint;
    
    cloneFirstPoint^.x := tempPoint^.x;
    cloneFirstPoint^.y := tempPoint^.y;

    while tempPoint <> nil do
    begin
        x := tempPoint^.x;
        y := tempPoint^.y;
        if reverse then
        begin
            tempPoint^.x := - y;
            tempPoint^.y := x;
        end
        else
        begin
            tempPoint^.x := y;
            tempPoint^.y := - x; 
        end;
        
        if  tempPoint^.x < shiftX then
            shiftX := tempPoint^.x;

        if  tempPoint^.y < shiftY then
            shiftY := tempPoint^.y;

        tempPoint := tempPoint^.next;
    end;

    shiftX := cloneFirstPoint^.x - tempFigure^.firstPoint^.x;
    shiftY := cloneFirstPoint^.y - tempFigure^.firstPoint^.y;

    dispose(cloneFirstPoint);

    setPosition(tempFigure, tempFigure^.x + shiftX, tempFigure^.y + shiftY);
end;

procedure renderHorizontalLine(y, startX, endX: integer);
var 
    i: integer;
begin
    for i := startX to endX do
    begin
        GotoXY(i, y);
        write('-');
    end;
end;

procedure renderVerticalLine(x, startY, endY: integer);
var 
    i: integer;
begin
    for i := startY to endY do
    begin
        GotoXY(x, i);
        write('|');
    end;
end;


procedure renderScreenBorders(var screen: pscreen);
begin
    renderVerticalLine(
        screen^.posX - 1, 
        screen^.posY - 1, 
        screen^.posY + screen^.height 
    );
    renderVerticalLine(
        screen^.posX + screen^.width, 
        screen^.posY - 1, 
        screen^.posY + screen^.height 
    );
    renderHorizontalLine(
        screen^.posY - 1,
        screen^.posX - 1,
        screen^.posX + screen^.width   
    );
    renderHorizontalLine(
        screen^.posY + screen^.height,
        screen^.posX - 1,
        screen^.posX + screen^.width   
    );
end;

procedure GetKey(var code: integer);
var
    c: char;
begin
    c := ReadKey;
    if c = #0 then
    begin
        c := ReadKey;
        code := -ord(c);
    end
    else
    begin
        code := ord(c);
    end
end;

procedure addNewFigure(var figure: pfigure);
begin
    new(figure);
    initRandomFigure(figure);
end;

procedure clonePoint(var point: ppoint; var newPoint: ppoint);
begin
    newPoint^.x := point^.x;
    newPoint^.y := point^.y;
end;

procedure cloneFigure(var figure: pfigure; var newFigure: pfigure);
var
    point, newPoint: ppoint;
begin
    newFigure^.firstPoint := nil;
    newFigure^.lastPoint  := nil;
    newFigure^.x          := figure^.x;
    newFigure^.y          := figure^.y;
    
    point := figure^.firstPoint;
    new(newFigure^.firstPoint);
    newPoint := newFigure^.firstPoint;

    while point <> nil do
    begin
        clonePoint(point, newPoint);
        point := point^.next;
        if point <> nil then
        begin
            new(newPoint^.next);
            newPoint := newPoint^.next;
        end;
    end;

    new(newFigure^.lastPoint);
    newFigure^.lastPoint := newPoint;
end;

function getCornerCoords(figure: pfigure): cornerCoords;
var
    x, y: integer;
    minX: integer = pointsCount + windowWidth;
    maxX: integer = -pointsCount;
    minY: integer = pointsCount + windowHeight;
    maxY: integer = -pointsCount;
    tempPoint: ppoint;
    tempArr: cornerCoords;
begin
    tempPoint := figure^.firstPoint;
    while tempPoint <> nil do
    begin
        x := figure^.x + tempPoint^.x;
        y := figure^.y + tempPoint^.y;
        if x < minX then
            minX := x;
        if x > maxX then
            maxX := x;
        if y < minY then
            minY := y;
        if y > maxY then
            maxY := y;
        tempPoint := tempPoint^.next;
    end;

    tempArr[1] := minX;
    tempArr[2] := maxX;
    tempArr[3] := minY;
    tempArr[4] := maxY;
    getCornerCoords := tempArr;
end;

function hasOverlap(
    figure: pfigure; 
    matrix: pmatrix; 
    newX, newY: integer
): boolean;
var
    x, y: integer;
    tempPoint: ppoint;
begin
    tempPoint := figure^.firstPoint;
    while tempPoint <> nil do
    begin
        x := newX + tempPoint^.x;
        y := newY + tempPoint^.y;
        if (x < 0) or (x > windowWidth - 1) then
        begin
            hasOverlap := true;
            exit;
        end;

        if (y < 0) or (y > windowHeight - 1) then
        begin
            hasOverlap := true;
            exit;
        end;

        if matrix^[x, y] = true then
        begin
            hasOverlap := true;
            exit;
        end;

        tempPoint := tempPoint^.next;
    end;
    hasOverlap := false;
end;

procedure moveLeft(
    var figure: pfigure; 
    var matrix: pmatrix; 
    var success: boolean
);
begin
    if hasOverlap(figure, matrix, figure^.x - 1, figure^.y) then
    begin
        success := false;
        exit;
    end;
    setPosition(figure, figure^.x - 1, figure^.y);
    success := true;
end;

procedure moveRight(
    var figure: pfigure; 
    var matrix: pmatrix; 
    var success: boolean
);
begin
    if hasOverlap(figure, matrix, figure^.x + 1, figure^.y) then
    begin
        success := false;
        exit;
    end;
    setPosition(figure, figure^.x + 1, figure^.y);
    success := true;
end;

procedure moveDown(
    var figure: pfigure; 
    var matrix: pmatrix; 
    var success: boolean
);
begin
    if hasOverlap(figure, matrix, figure^.x, figure^.y + 1) then
    begin
        success := false;
        exit;
    end;
    setPosition(figure, figure^.x, figure^.y + 1);
    success := true;
end;

procedure fixIfPositionOutOfBorders(var figure: pfigure);
var
    cornerCoordsArr: cornerCoords;
    minX, maxX, minY, maxY: integer;
begin
    cornerCoordsArr := getCornerCoords(figure);
    minX := cornerCoordsArr[1];
    maxX := cornerCoordsArr[2];
    minY := cornerCoordsArr[3];
    maxY := cornerCoordsArr[4];
    
    if (minX < 0) then 
        setPosition(figure, figure^.x - minX, figure^.y);
    if (maxX > windowWidth - 1) then 
        setPosition(figure, figure^.x - (maxX - (windowWidth - 1)), figure^.y);
    if (minY < 0) then
        setPosition(figure, figure^.x, figure^.y - minY);
    if (maxY > windowHeight - 1) then 
        setPosition(figure, figure^.x, figure^.y - (maxY - (windowHeight - 1)));
end;

procedure rotate(
    var figure: pfigure; 
    var matrix: pmatrix; 
    var success: boolean
);
var
    tempFigure: pfigure; 
begin
    new(tempFigure);
    cloneFigure(figure, tempFigure);
    rotateFigure(tempFigure, false);
    
    fixIfPositionOutOfBorders(tempFigure);

    if not hasOverlap(tempFigure, matrix, tempFigure^.x, tempFigure^.y) then
    begin
        destroyFigure(figure);
        figure := tempFigure;
        success := true;
        exit;                
    end;
    
    destroyFigure(tempFigure);
end;

procedure initMatrix(var matrix: pmatrix);
var
    i, j: integer;
begin
    for i := 0 to windowWidth - 1 do
    begin
        for j := 0 to windowHeight - 1 do
        begin
            matrix^[i, j] := false;
        end;
    end;
end;

procedure renderMatrix(var screen: pscreen; var matrix: pmatrix; ch: char);
var
    i, j: integer;
begin
    for i := 0 to windowWidth - 1 do
    begin
        for j := 0 to windowHeight - 1 do
        begin
            if matrix^[i, j] = true then 
                printPoint(screen, i, j, ch);
        end;
    end;
end;

procedure addFigureToMatrix(var figure: pfigure; var matrix: pmatrix);
var
    rootX, rootY: integer;
    tempPoint: ppoint;
begin
    rootX := figure^.x;
    rootY := figure^.y;
    tempPoint := figure^.firstPoint;
    while tempPoint <> nil do
    begin
        matrix^[rootX + tempPoint^.x][rootY + tempPoint^.y] := true;
        tempPoint := tempPoint^.next;
    end;
end;

function isFullRow(y: integer; var matrix: pmatrix): boolean;
var 
    x: integer;
begin
    for x := 0 to windowWidth - 1 do
    begin
        if matrix^[x][y] <> true then
        begin
            isFullRow := false;
            exit;
        end;
    end;
    isFullRow := true;
end;

function isEmptyRow(y: integer; var matrix: pmatrix): boolean;
var 
    x: integer;
begin
    for x := 0 to windowWidth - 1 do
    begin
        if matrix^[x][y] <> false then
        begin
            isEmptyRow := false;
            exit;
        end;
    end;
    isEmptyRow := true;
end;


procedure emptyRow(y: integer; var matrix: pmatrix);
var
    x: integer;
begin
    for x := 0 to windowWidth - 1 do
    begin
        matrix^[x][y] := false;
    end; 
end;

procedure fillRow(y: integer; var matrix: pmatrix);
var
    x: integer;
begin
    for x := 0 to windowWidth - 1 do
    begin
        matrix^[x][y] := true;
    end; 
end;

procedure copyRow(fromY, toY: integer; var matrix: pmatrix);
var
    x: integer;
begin
    for x := 0 to windowWidth - 1 do
    begin
        matrix^[x][toY] := matrix^[x][fromY];
    end; 
end;

procedure processMatrix(var matrix: pmatrix; var countRowDeleted: integer);
var
    y, subY: integer;
begin
    y := windowHeight - 1;
    while (y > 0) and (not isEmptyRow(y, matrix)) do
    begin
        if isFullRow(y, matrix) then
        begin
            countRowDeleted := countRowDeleted + 1;
            subY := y;
            while (subY > 0) and (not isEmptyRow(subY, matrix)) do
            begin
                emptyRow(subY, matrix);
                copyRow(subY  - 1, subY, matrix);
                subY := subY - 1;
            end; 
        end
        else
        begin
            y := y - 1;
        end;
    end;
end;

procedure rebuildMatrixAndDestroyFigure(
    var figure: pfigure;
    var matrix: pmatrix;
    var screen: pscreen;
    var score: integer
); 
var 
    countRowsDeleted: integer = 0;
begin
    addFigureToMatrix(figure, matrix);
    score := score + 10;
    renderMatrix(screen, matrix, filler);
    delay(defaultTickMs div 2);
    renderMatrix(screen, matrix, ' '); 
    processMatrix(matrix, countRowsDeleted);
    score := score + 50 * countRowsDeleted; 
    renderMatrix(screen, matrix, filler);
    destroyFigure(figure);
end;

procedure skipDown(
    var figure: pfigure;
    var matrix: pmatrix;
    var screen: pscreen;
    var score: integer
);
var 
    moved: boolean = true;
begin
    printFigure(screen, figure, ' ');
    repeat
        moveDown(figure, matrix, moved);
    until moved = false;
    rebuildMatrixAndDestroyFigure(figure, matrix, screen, score);
end;

procedure renderControlInfo(var screen: pscreen);
var
    x, y, i: integer;
    infoBlocks: array [0..7] of string;
begin
    infoBlocks[0] := 'Control buttons: ';
    infoBlocks[1] := ' ';
    infoBlocks[2] := '< - to move left';
    infoBlocks[3] := '> - to move right';
    infoBlocks[4] := '^ - to rotate';
    infoBlocks[5] := '<space> - to stick down';
    infoBlocks[6] := '<esc> - to exit';
    infoBlocks[7] := '<p> - to pause';

    x := screen^.posX + screen^.width + 3;
    y := screen^.posY + (screen^.height div 2) - 2;
    for i := 0 to 7 do
    begin
        GotoXY(x, y + i);
        write(infoBlocks[i]);
    end;
end;

procedure renderBlinkingString(x, y, tickMs: integer; message: string);
var
    i, slength, startX, startY: integer;
begin
    slength := length(message);
    startX := x - (slength div 2);
    startY := y - 1;
    GotoXY(startX, startY);
    write(message);
    delay(tickMs);
    GotoXY(startX, startY);
    for i := 0 to slength do
    begin
        write(' ');
    end;
    delay(tickMs);
end;


procedure waitingScreen(var screen: pscreen; var isStarted: boolean);
var
    x, y: integer;
begin
    x := screen^.posX + screen^.width div 2;
    y := screen^.posY + screen^.height div 2;
    while true do
    begin
        if keypressed then
        begin
            GetKey(key);
            if key = 13 then
            begin
                score := 0;
                isStarted := true;
                renderControlInfo(screen);
                exit;
            end; 
        end;
        renderBlinkingString(x, y, 500, 'Press <Enter> to start')
    end;
end;

procedure startupScreen(var screen: pscreen; var matrix: pmatrix);
var
    i: integer;
begin
    for i := 0 to windowHeight - 1 do
    begin
        renderMatrix(screen, matrix, ' ');
        fillRow(windowHeight - 1 - i, matrix);
        renderMatrix(screen, matrix, filler);
        delay(70);
    end;

    for i := 0 to windowHeight - 1 do
    begin
        renderMatrix(screen, matrix, ' ');
        emptyRow(i, matrix);
        renderMatrix(screen, matrix, filler);
        delay(70);
    end;
end;

procedure renderScore(var screen: pscreen; score: integer);
var
    x, y: integer;
begin
    x := screen^.posX + (screen^.width div 2) - 5;
    y := screen^.posY + screen^.height + 2;
    GotoXY(x, y);
    write('                                      ');
    GotoXY(x, y);
    write('Score: ', score);
end;

procedure renderNextFigure(
    var screen: pscreen; 
    var figure: pfigure; 
    filler: char
);
var
    x, y: integer;
begin
    x := screen^.posX - 13;
    y := screen^.posY + (screen^.height div 2) - 2;
    GotoXY(x, y);
    write('Next thing:'); 
    figure^.x := -4;
    figure^.y := windowHeight div 2 + 1;
    printFigure(screen, figure, filler); 
end;

procedure replaceFigure(
    var screen: pscreen;
    var currentFigure: pfigure;
    var nextFigure: pfigure
);
begin
    new(currentFigure);
    cloneFigure(nextFigure, currentFigure);
    renderNextFigure(mainScreen, nextFigure, ' ');
    setPosition(
        currentFigure, 
        (windowWidth div 2) - 1, 
        0
    );
    addNewFigure(nextFigure);
    renderNextFigure(mainScreen, nextFigure, filler);
end;

procedure waitingPause(var screen: pscreen; var isPaused: boolean);
var
    x, y: integer;
    key: integer = 0;
begin
    x := screen^.posX + screen^.width + 6;
    y := screen^.posY + (screen^.height div 2) + 7;
    while isPaused do
    begin
        if keypressed then
        begin
            GetKey(key);
            if key = 112 then
                isPaused := false;
        end;
        renderBlinkingString(x, y + 1, 500, '<pause>')
    end;
end;

begin
    clrscr;
    randomize;
 
    new(mainMatrix);
    initMatrix(mainMatrix);

    new(mainScreen);
    mainScreen^.width := windowWidth * pointWidth;
    mainScreen^.height := windowHeight * pointHeight;
    
    if (mainScreen^.width + 40) > ScreenWidth then
    begin
        writeln('Not enough screen width, please resize window');
        exit;
    end;

    if (mainScreen^.height + 10) > ScreenHeight then
    begin
        writeln('Not enough screen height, please resize window');
        exit;
    end;

    mainScreen^.posX := ((ScreenWidth - (mainScreen^.width + 40)) div 2) + 20;
    mainScreen^.posY := 3;
    renderScreenBorders(mainScreen);
    startupScreen(mainScreen, mainMatrix);

    tickTime := defaultTickMs;

    addNewFigure(nextFigure);
    
    while true do
    begin
        if not isStarted then
            waitingScreen(mainScreen, isStarted);

        if iFigure = nil then
        begin
            replaceFigure(mainScreen, iFigure, nextFigure);
            if hasOverlap(iFigure, mainMatrix, iFigure^.x, iFigure^.y) then
            begin
                addFigureToMatrix(iFigure, mainMatrix);
                renderMatrix(mainScreen, mainMatrix, filler);
                destroyFigure(iFigure);   
                initMatrix(mainMatrix); 
                startupScreen(mainScreen, mainMatrix);
                isStarted := false;
                continue;
            end;
        end;
        
        if tickTime > 0 then
            printFigure(mainScreen, iFigure, '#'); 
        
        if isPaused then
            waitingPause(mainScreen, isPaused);

        if tickTime > 0 then
            delay(tickTime);

        printFigure(mainScreen, iFigure, ' '); 

        if keypressed then
        begin
            GetKey(key);
            tickTime := defaultTickMs div 2;
            moved := false;
            case key of 
                -75:
                    moveLeft(iFigure, mainMatrix, moved);
                -77:
                    moveRight(iFigure, mainMatrix, moved);
                -72:
                    rotate(iFigure, mainMatrix, moved);
                -80:
                    tickTime := defaultTickMs div 2;
                 32:
                    skipDown(iFigure, mainMatrix, mainScreen, score);
                 112: 
                    isPaused := true;
                 27:
                    break;
            end;
            if moved then 
            begin
                tickTime := defaultTickMs div 2;
            end
            else
                tickTime := 0;
            begin
            end;
        end
        else
        begin
            moveDown(iFigure, mainMatrix, moved);
            if moved = false then
                rebuildMatrixAndDestroyFigure(
                    iFigure, 
                    mainMatrix, 
                    mainScreen,
                    score
                );
            tickTime := defaultTickMs;
        end;   
        renderScore(mainScreen, score); 
    end;
    clrscr;
end.
