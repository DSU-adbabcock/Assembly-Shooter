%include "/usr/local/share/csc314/asm_io.inc"

%define TICK    10000

; the file that stores the initial state
%define BOARD_FILE 'board.txt'

; how to represent everything
%define WALL_CHAR '#'
%define PLAYER_CHAR 'O'
%define PLAYER2_CHAR 'X'
%define LEFTBULLET '<'
%define RIGHTBULLET '>'

; the size of the game screen in characters
%define HEIGHT 20
%define WIDTH 40

; the player starting position.
; top left is considered (0,0)
%define STARTX 2
%define STARTY 10

%define STARTX2 37
%define STARTY2 10

;max bullets allowed/lifetime
%define MAXBULLET 1
%define BULLETLIFE 40

; these keys do things
%define EXITCHAR 'x'
%define UPCHAR 'w'
%define LEFTCHAR 'a'
%define DOWNCHAR 's'
%define RIGHTCHAR 'd'
%define LEFTSHOOT 'q'
%define RIGHTSHOOT 'e'


%define UPCHAR2 'i'
%define LEFTCHAR2 'j'
%define DOWNCHAR2 'k'
%define RIGHTCHAR2 'l'
%define LEFTSHOOT2 'u'
%define RIGHTSHOOT2 'o'


segment .data

        ; used to fopen() the board file defined above
        board_file                      db BOARD_FILE,0

        ; used to change the terminal mode
        mode_r                          db "r",0
        raw_mode_on_cmd         db "stty raw -echo",0
        raw_mode_off_cmd        db "stty -raw echo",0

        ; called by system() to clear/refresh the screen
        clear_screen_cmd        db "clear",0

        ; things the program will print
        help_str                        db 13,10,"Controls: ", \
                                                        UPCHAR,"=UP / ", \
                                                        LEFTCHAR,"=LEFT / ", \
                                                        DOWNCHAR,"=DOWN / ", \
                                                        RIGHTCHAR,"=RIGHT / ", \
                                                        LEFTSHOOT,"=SHOOT LEFT / ", \
                                                        RIGHTSHOOT,"=SHOOT RIGHT / ", \
                                                        EXITCHAR,"=EXIT", 13,10,0

        help_str2                       db 13,"Controls (Player 2): ", \
                                                        UPCHAR2,"=UP / ", \
                                                        LEFTCHAR2,"=LEFT / ", \
                                                        DOWNCHAR2,"=DOWN / ", \
                                                        RIGHTCHAR2,"=RIGHT / ", \
                                                        LEFTSHOOT2,"=SHOOT LEFT / ", \
                                                        RIGHTSHOOT2,"=SHOOT RIGHT / ", 13,10,0

        p1_win_message          db      "Wow you did it I'm proud of you player 1!", 10, 10, 0
        p2_win_message          db      "Are you a pro at quake or something player 2?", 10, 10, 0

        ;hp counters
        player1_hp                      dd      3
        player2_hp                      dd      3
        ;counters for bullets onscreen
        bulletcount                     dd      0
        bulletcount2            dd      0
        ;flag for right/left bullet used in render
        is_right                        dd      0
        is_right2                       dd      0
        ;time since bullet shot
        since_shot              dd      0
        since_shot2             dd      0

segment .bss

        ; this array stores the current rendered gameboard (HxW)
        board   resb    (HEIGHT * WIDTH)

        ; these variables store the current player position
        xpos    resd    1
        ypos    resd    1

        xpos2   resd    1
        ypos2   resd    1
        ;bullet positions
        xbullet         resd    1
        ybullet         resd    1

        xbullet2        resd    1
        ybullet2        resd    1

segment .text

        global  asm_main
        extern  system
        extern  putchar
        extern  getchar
        extern  printf
        extern  fopen
        extern  fread
        extern  fgetc
        extern  fclose
        extern  time
        extern  srand
        extern  rand
        extern  usleep
        extern  fcntl

asm_main:
        enter   0,0
        pusha
        ;***************CODE STARTS HERE***************************

        ; put the terminal in raw mode so the game works nicely
        call    raw_mode_on

        ; read the game board file into the global variable
        call    init_board

        ; set the player at the proper start position
        mov             DWORD [xpos], STARTX
        mov             DWORD [ypos], STARTY

        mov             DWORD [xpos2], STARTX2
        mov             DWORD [ypos2], STARTY2


        ; the game happens in this loop
        ; the steps are...
        ;   1. render (draw) the current board
        ;   2. get a character from the user
        ;       3. store current xpos,ypos in esi,edi
        ;       4. update xpos,ypos based on character from user
        ;       5. check what's in the buffer (board) at new xpos,ypos
        ;       6. if it's a wall, reset xpos,ypos to saved esi,edi
        ;       7. otherwise, just continue! (xpos,ypos are ok)
        game_loop:

                push    TICK
                call    usleep
                add             esp, 4

                ; draw the game board
                call    render

                ; update existing bullets
                mov             eax, DWORD[bulletcount]
                cmp             eax, 0
                je              update_end

                inc             DWORD[since_shot]
                mov             eax, BULLETLIFE
                cmp             eax, DWORD[since_shot]
                ;bullet has passed max lifetime
                je              dead_bullet

                mov             eax, DWORD[is_right]
                cmp             eax, 1
                je              update_right

                ;update leftwards
                dec             DWORD[xbullet]
                jmp             update_end
                update_right:
                        inc             DWORD[xbullet]
                        jmp             update_end

                update_end:

                mov             eax, DWORD[bulletcount2]
                cmp             eax, 0
                je              update_end2

                inc             DWORD[since_shot2]
                mov             eax, BULLETLIFE
                cmp             eax, DWORD[since_shot2]
                ;bullet has passed max lifetime
                je              dead_bullet2

                mov             eax, DWORD[is_right2]
                cmp             eax, 1
                je              update_right2

                ;update leftwards
                dec             DWORD[xbullet2]
                jmp             update_end2
                update_right2:
                        inc             DWORD[xbullet2]
                        jmp             update_end2
                update_end2:


                ; perform bullet collision detection
                ; store char positions in registers for easy use
                ;(nonblocking_getchar probably screws with them so redo it later to be safe)
                ;I think because of the way I did collision and movement at different times you can "parry" a bullet by moving into it at the perfect time and dodge it haha
                mov             esi, [xpos]
                mov             edi, [ypos]
                mov             ebx, [xpos2]
                mov             ecx, [ypos2]

                cmp             esi, DWORD[xbullet2]
                jne             check_p2_hit
                cmp             edi, DWORD[ybullet2]
                jne             check_p2_hit
                        ;bullet hit p1
                        dec             DWORD[player1_hp]
                        mov             eax, 0
                        cmp             eax, DWORD[player1_hp]
                        je              p2_win
                        jmp             dead_bullet2

                check_p2_hit:

                cmp             ebx, DWORD[xbullet]
                jne             finish_hit_check
                cmp             ecx, DWORD[ybullet]
                jne             finish_hit_check
                        ;bullet hit p2
                        dec             DWORD[player2_hp]
                        mov             eax, 0
                        cmp             eax, DWORD[player2_hp]
                        je              p1_win
                        jmp             dead_bullet

                ;reset bullet when its life runs out or it hits someone
                dead_bullet:
                        dec             DWORD[bulletcount]
                        mov             DWORD[since_shot], 0
                        mov             DWORD[is_right], 0
                        mov             DWORD[xbullet], 0
                        mov             DWORD[ybullet], 0
                        jmp             finish_hit_check
                dead_bullet2:
                        dec             DWORD[bulletcount2]
                        mov             DWORD[since_shot2], 0
                        mov             DWORD[is_right2], 0
                        mov             DWORD[xbullet2], 0
                        mov             DWORD[ybullet2], 0
                        jmp             finish_hit_check
                finish_hit_check:

                ; get an action from the user
                call    nonblocking_getchar

                cmp             al, -1
                jne             got_char
                        jmp             game_loop
                got_char:
                ; store the current position
                ; we will test if the new position is legal
                ; if not, we will restore these
                mov             esi, [xpos]
                mov             edi, [ypos]
                mov             ebx, [xpos2]
                mov             ecx, [ypos2]



                ; choose what to do
                cmp             eax, EXITCHAR
                je              game_loop_end
                cmp             eax, UPCHAR
                je              move_up
                cmp             eax, LEFTCHAR
                je              move_left
                cmp             eax, DOWNCHAR
                je              move_down
                cmp             eax, RIGHTCHAR
                je              move_right
                cmp             eax, RIGHTSHOOT
                je              shoot_right
                cmp             eax, LEFTSHOOT
                je              shoot_left

                cmp             eax, UPCHAR2
                je              move_up2
                cmp             eax, LEFTCHAR2
                je              move_left2
                cmp             eax, DOWNCHAR2
                je              move_down2
                cmp             eax, RIGHTCHAR2
                je              move_right2
                cmp             eax, RIGHTSHOOT2
                je              shoot_right2
                cmp             eax, LEFTSHOOT2
                je              shoot_left2

                jmp             input_end                       ; or just do nothing

                ;perform action input
                move_up:
                        dec             DWORD [ypos]
                        jmp             input_end
                move_left:
                        dec             DWORD [xpos]
                        jmp             input_end
                move_down:
                        inc             DWORD [ypos]
                        jmp             input_end
                move_right:
                        inc             DWORD [xpos]
                        jmp             input_end
                shoot_left:
                        ;check if bullet is already on screen, if so fire a bullet in the proper direction
                        mov             eax, DWORD[bulletcount]
                        cmp             eax, MAXBULLET
                        jge             game_loop
                        dec             esi
                        mov             DWORD[xbullet], esi
                        mov             DWORD[ybullet], edi
                        inc             DWORD [bulletcount]
                        jmp             game_loop

                shoot_right:
                        mov             eax, DWORD[bulletcount]
                        cmp             eax, MAXBULLET
                        jge             game_loop
                        ;flag for right facing bullet set so the proper character can be printed/direction can be used
                        mov             DWORD[is_right], 1
                        inc             esi
                        mov             DWORD[xbullet], esi
                        mov             DWORD[ybullet], edi
                        inc             DWORD [bulletcount]
                        jmp             game_loop

                move_up2:
                        dec             DWORD [ypos2]
                        jmp             input_end
                move_left2:
                        dec             DWORD [xpos2]
                        jmp             input_end
                move_down2:
                        inc             DWORD [ypos2]
                        jmp             input_end
                move_right2:
                        inc             DWORD [xpos2]
                        jmp             input_end
                shoot_left2:
                        mov             eax, DWORD[bulletcount2]
                        cmp             eax, MAXBULLET
                        jge             game_loop
                        dec             ebx
                        mov             DWORD[xbullet2], ebx
                        mov             DWORD[ybullet2], ecx
                        inc             DWORD [bulletcount2]
                        jmp             game_loop

                shoot_right2:
                        mov             eax, DWORD[bulletcount2]
                        cmp             eax, MAXBULLET
                        jge             game_loop
                        mov             DWORD[is_right2], 1
                        inc             ebx
                        mov             DWORD[xbullet2], ebx
                        mov             DWORD[ybullet2], ecx
                        inc             DWORD [bulletcount2]
                        jmp             game_loop
                input_end:

                ; (W * y) + x = pos

                ; compare the current position to the wall character
                mov             eax, WIDTH
                mul             DWORD [ypos]
                add             eax, [xpos]
                lea             eax, [board + eax]
                cmp             BYTE [eax], WALL_CHAR
                jne             valid_move_wall
                        ; opps, that was an invalid move, reset

                        mov             DWORD [xpos], esi
                        mov             DWORD [ypos], edi

                valid_move_wall:
                cmp             DWORD [xpos], ebx
                jne             valid_move
                cmp             DWORD [ypos], ecx
                jne             valid_move

                        ;ran into p2
                        mov             DWORD[xpos], esi
                        mov             DWORD[ypos], edi

                valid_move:
                mov             eax, WIDTH
                mul             DWORD [ypos2]
                add             eax, [xpos2]
                lea             eax, [board + eax]
                cmp             BYTE [eax], WALL_CHAR
                jne             valid_move2_wall

                        ;player 2 made invalid move
                        mov             DWORD [xpos2], ebx
                        mov             DWORD [ypos2], ecx

                valid_move2_wall:
                cmp             DWORD [xpos2], esi
                jne             valid_move2
                cmp             DWORD [ypos2], edi
                jne             valid_move2
                        ;ran into p1
                        mov             DWORD[xpos2], ebx
                        mov             DWORD[ypos2], ecx

        valid_move2:
        jmp             game_loop
        p1_win:
        push    p1_win_message
        call    printf
        add             esp, 4
        jmp             game_loop_end
        p2_win:
        push    p2_win_message
        call    printf
        add             esp, 4
        game_loop_end:
        call raw_mode_off

        ;***************CODE ENDS HERE*****************************
        popa
        mov             eax, 0
        leave
        ret

; === FUNCTION ===
raw_mode_on:

        push    ebp
        mov             ebp, esp

        push    raw_mode_on_cmd
        call    system
        add             esp, 4

        mov             esp, ebp
        pop             ebp
        ret

; === FUNCTION ===
raw_mode_off:

        push    ebp
        mov             ebp, esp

        push    raw_mode_off_cmd
        call    system
        add             esp, 4

        mov             esp, ebp
        pop             ebp
        ret

; === FUNCTION ===
init_board:

        push    ebp
        mov             ebp, esp

        ; FILE* and loop counter
        ; ebp-4, ebp-8
        sub             esp, 8

        ; open the file
        push    mode_r
        push    board_file
        call    fopen
        add             esp, 8
        mov             DWORD [ebp-4], eax

        ; read the file data into the global buffer
        ; line-by-line so we can ignore the newline characters
        mov             DWORD [ebp-8], 0
        read_loop:
        cmp             DWORD [ebp-8], HEIGHT
        je              read_loop_end

                ; find the offset (WIDTH * counter)
                mov             eax, WIDTH
                mul             DWORD [ebp-8]
                lea             ebx, [board + eax]

                ; read the bytes into the buffer
                push    DWORD [ebp-4]
                push    WIDTH
                push    1
                push    ebx
                call    fread
                add             esp, 16

                ; slurp up the newline
                push    DWORD [ebp-4]
                call    fgetc
                add             esp, 4

        inc             DWORD [ebp-8]
        jmp             read_loop
        read_loop_end:

        ; close the open file handle
        push    DWORD [ebp-4]
        call    fclose
        add             esp, 4

        mov             esp, ebp
        pop             ebp
        ret

; === FUNCTION ===
render:

        push    ebp
        mov             ebp, esp

        ; 4 ints, for four loop counters
        ; ebp-4, ebp-8
        sub             esp, 16

        ; clear the screen
        push    clear_screen_cmd
        call    system
        add             esp, 4

        ; print the help information
        push    help_str
        call    printf
        add             esp, 4
        push    help_str2
        call    printf
        add             esp, 4
        ; outside loop by height
        ; i.e. for(c=0; c<height; c++)
        mov             DWORD [ebp-4], 0
        y_loop_start:
        cmp             DWORD [ebp-4], HEIGHT
        je              y_loop_end

                ; inside loop by width
                ; i.e. for(c=0; c<width; c++)
                mov             DWORD [ebp-8], 0
                x_loop_start:
                cmp             DWORD [ebp-8], WIDTH
                je              x_loop_end

                        ; check if (xpos,ypos)=(x,y)
                        mov             eax, [xpos]
                        cmp             eax, DWORD [ebp-8]
                        jne             check_p2
                        mov             eax, [ypos]
                        cmp             eax, DWORD [ebp-4]
                        jne             check_p2

                                ; if both were equal, print the player
                                push    PLAYER_CHAR
                                jmp             print_end

                        check_p2:
                        mov             eax, [xpos2]
                        cmp             eax, DWORD [ebp-8]
                        jne             check_bullet
                        mov             eax, [ypos2]
                        cmp             eax, DWORD [ebp-4]
                        jne             check_bullet

                        push    PLAYER2_CHAR
                        jmp             print_end


                        check_bullet:
                        ;extremely similar to checking for characters
                        mov             eax, DWORD[xbullet]
                        cmp             eax, DWORD [ebp-8]
                        jne             check_bullet2
                        mov             eax, DWORD[ybullet]
                        cmp             eax, DWORD [ebp-4]
                        jne             check_bullet2

                                mov             eax, DWORD[is_right]
                                cmp             eax, 1
                                je              print_right

                                push    LEFTBULLET
                                jmp             print_end
                                print_right:
                                push    RIGHTBULLET
                                jmp             print_end


                        check_bullet2:
                        mov             eax, DWORD[xbullet2]
                        cmp             eax, DWORD [ebp-8]
                        jne             print_board
                        mov             eax, DWORD[ybullet2]
                        cmp             eax, DWORD [ebp-4]
                        jne             print_board

                                mov             eax, DWORD[is_right2]
                                cmp             eax, 1
                                je              print_right2

                                push    LEFTBULLET
                                jmp             print_end
                                print_right2:
                                push    RIGHTBULLET
                                jmp             print_end

                        print_board:
                                ; otherwise print whatever's in the buffer
                                mov             eax, [ebp-4]
                                mov             ebx, WIDTH
                                mul             ebx
                                add             eax, [ebp-8]
                                mov             ebx, 0
                                mov             bl, BYTE [board + eax]
                                push    ebx
                        print_end:
                        call    putchar
                        add             esp, 4

                inc             DWORD [ebp-8]
                jmp             x_loop_start
                x_loop_end:

                ; write a carriage return (necessary when in raw mode)
                push    0x0d
                call    putchar
                add             esp, 4

                ; write a newline
                push    0x0a
                call    putchar
                add             esp, 4

        inc             DWORD [ebp-4]
        jmp             y_loop_start
        y_loop_end:

        mov             esp, ebp
        pop             ebp
        ret

; === FUNCTION ===
nonblocking_getchar:

; returns -1 on no-data
; returns char on succes

; magic values
%define F_GETFL 3
%define F_SETFL 4
%define O_NONBLOCK 2048
%define STDIN 0

        push    ebp
        mov             ebp, esp

        ; single int used to hold flags
        ; single character (aligned to 4 bytes) return
        sub             esp, 8

        ; get current stdin flags
        ; flags = fcntl(stdin, F_GETFL, 0)
        push    0
        push    F_GETFL
        push    STDIN
        call    fcntl
        add             esp, 12
        mov             DWORD [ebp-4], eax

        ; set non-blocking mode on stdin
        ; fcntl(stdin, F_SETFL, flags | O_NONBLOCK)
        or              DWORD [ebp-4], O_NONBLOCK
        push    DWORD [ebp-4]
        push    F_SETFL
        push    STDIN
        call    fcntl
        add             esp, 12

        call    getchar
        mov             DWORD [ebp-8], eax

        ; restore blocking mode
        ; fcntl(stdin, F_SETFL, flags ^ O_NONBLOCK
        xor             DWORD [ebp-4], O_NONBLOCK
        push    DWORD [ebp-4]
        push    F_SETFL
        push    STDIN
        call    fcntl
        add             esp, 12

        mov             eax, DWORD [ebp-8]

        mov             esp, ebp
        pop             ebp
