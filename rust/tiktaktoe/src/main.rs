#![allow(warnings)]
use getch_rs::{Getch, Key};

enum GameStatus {
    None,
    Win(u8),
    Draw,
}

struct Player {
    c: char,
    id: u8,
}

struct Game {
    players: [Player; 2],
    board: [[char; 3]; 3],
    turn: u8,
    status: GameStatus,
}

impl Game {
    pub fn new() -> Self {
        const p1: Player = Player { c: 'X', id: 1 };
        const p2: Player = Player { c: 'O', id: 2 };
        const players: [Player; 2] = [p1, p2];
        let mut board: [[char; 3]; 3] = [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']];
        Self {
            players,
            board,
            turn: 1,
            status: GameStatus::None,
        }
    }

    pub fn print(&self) {
        let mut s = String::new();
        for row in &self.board {
            for (i, &cell) in row.iter().enumerate() {
                s.push(cell as char);
                if i != 2 {
                    s.push_str(" | ");
                }
            }
            s.push('\n');
        }
        println!("{}", s);
    }

    fn toggleTurn(&mut self) {
        if self.turn == 1 {
            self.turn = 2;
        } else {
            self.turn = 1;
        }
    }

    fn checkStatus(&mut self) {
        let mut isDraw = true;

        for p in &self.players {
            if self.board[0][0] == self.board[1][1]
                && self.board[1][1] == self.board[2][2]
                && self.board[1][1] == p.c
            {
                self.status = GameStatus::Win(p.id);
                return;
            }

            if self.board[2][0] == self.board[1][1]
                && self.board[1][1] == self.board[0][2]
                && self.board[1][1] == p.c
            {
                self.status = GameStatus::Win(p.id);
                return;
            }

            let mut i = 0;
            while i < 3 {
                if self.board[0][i] == self.board[1][i]
                    && self.board[1][i] == self.board[2][i]
                    && self.board[1][i] == p.c
                {
                    self.status = GameStatus::Win(p.id);
                    return;
                }

                if self.board[i][0] == self.board[i][1]
                    && self.board[i][1] == self.board[i][2]
                    && self.board[i][1] == p.c
                {
                    self.status = GameStatus::Win(p.id);
                    return;
                }
                i += 1;
            }
        }

        let mut i = 0;
        while i < 3 {
            let mut j = 0;
            while j < 3 {
                if self.board[i][j] != self.players[0].c && self.board[i][j] != self.players[1].c {
                    isDraw = false;
                }
                j += 1;
            }
            i += 1;
        }

        if isDraw {
            self.status = GameStatus::Draw;
        }
    }

    fn checkChoice(&mut self, c: char) {
        if c.is_digit(10) {
            let mut flag = true;
            let num = c.to_digit(10).unwrap();
            if num > 0 {
                let row = ((num - 1) / 3) as usize;
                let col = ((num - 1) % 3) as usize;
                for p in &self.players {
                    if p.c == self.board[row][col] {
                        flag = false;
                    }
                }

                if flag {
                    self.board[row][col] = self.players[(self.turn - 1) as usize].c;
                    self.toggleTurn();
                    self.checkStatus();
                }
            }
        }
    }

    pub fn run(&mut self) {
        let mut g = Getch::new();
        while matches!(self.status, GameStatus::None) {
            self.print();
            match g.getch().unwrap() {
                Key::Char('q') | Key::Char('Q') => {
                    println!("Exitting...\n");
                    break;
                }
                Key::Char(c) => {
                    self.checkChoice(c);
                }
                other => {}
            }
        }
        self.print();
        if matches!(self.status, GameStatus::Win(1)) {
            println!("Player 1 is the winner of this game!\n");
        } else if matches!(self.status, GameStatus::Win(2)) {
            println!("Player 2 is the winner of this game!\n");
        } else if matches!(self.status, GameStatus::Draw) {
            println!("The game ended in draw!\n");
        }
    }
}

fn main() {
    let mut game = Game::new();
    game.run();
}

// Thanks for watching!
