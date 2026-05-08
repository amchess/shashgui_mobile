import 'package:flutter/material.dart';

class SetupPositionDialog extends StatefulWidget {
  final String initialFen;

  const SetupPositionDialog({super.key, required this.initialFen});

  @override
  State<SetupPositionDialog> createState() => _SetupPositionDialogState();
}

class _SetupPositionDialogState extends State<SetupPositionDialog> {
  static const Map<String, String> _symbols = {
    'K': '♔',
    'Q': '♕',
    'R': '♖',
    'B': '♗',
    'N': '♘',
    'P': '♙',
    'k': '♚',
    'q': '♛',
    'r': '♜',
    'b': '♝',
    'n': '♞',
    'p': '♟',
    '.': '',
  };

  late List<List<String>> _grid;
  String _selectedPiece = 'P'; // Pedone bianco di default
  bool _isWhiteTurn = true;

  bool _castleK = false;
  bool _castleQ = false;
  bool _castlek = false;
  bool _castleq = false;

  String _epSquare = "-";
  int _halfMove = 0;
  int _fullMove = 1;

  final TextEditingController _fenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initGrid();
    _loadFen(widget.initialFen);
  }

  void _initGrid() {
    _grid = List.generate(8, (_) => List.generate(8, (_) => '.'));
  }

  void _loadFen(String fen) {
    try {
      _initGrid();
      List<String> parts = fen.split(' ');
      if (parts.isEmpty) return;

      // 1. Pezzi
      List<String> rows = parts[0].split('/');
      for (int r = 0; r < 8 && r < rows.length; r++) {
        int c = 0;
        for (int i = 0; i < rows[r].length; i++) {
          String char = rows[r][i];
          if (int.tryParse(char) != null) {
            c += int.parse(char);
          } else {
            _grid[r][c] = char;
            c++;
          }
        }
      }

      // 2. Turno, Arrocco, Contatori
      if (parts.length > 1) _isWhiteTurn = parts[1] == 'w';
      if (parts.length > 2) {
        _castleK = parts[2].contains('K');
        _castleQ = parts[2].contains('Q');
        _castlek = parts[2].contains('k');
        _castleq = parts[2].contains('q');
      }
      if (parts.length > 3) _epSquare = parts[3];
      if (parts.length > 4) _halfMove = int.tryParse(parts[4]) ?? 0;
      if (parts.length > 5) _fullMove = int.tryParse(parts[5]) ?? 1;

      _updateFenText();
    } catch (e) {
      debugPrint("Errore parsing FEN: $e");
    }
  }

  void _updateFenText() {
    _fenController.text = _generateFen();
  }

  String _generateFen() {
    List<String> fenRows = [];
    for (int r = 0; r < 8; r++) {
      int emptyCount = 0;
      String rowStr = "";
      for (int c = 0; c < 8; c++) {
        if (_grid[r][c] == '.') {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            rowStr += emptyCount.toString();
            emptyCount = 0;
          }
          rowStr += _grid[r][c];
        }
      }
      if (emptyCount > 0) rowStr += emptyCount.toString();
      fenRows.add(rowStr);
    }

    String placement = fenRows.join('/');
    String turn = _isWhiteTurn ? 'w' : 'b';
    String castling = "";
    if (_castleK) castling += "K";
    if (_castleQ) castling += "Q";
    if (_castlek) castling += "k";
    if (_castleq) castling += "q";
    if (castling.isEmpty) castling = "-";

    return "$placement $turn $castling $_epSquare $_halfMove $_fullMove";
  }

  void _onSquareTapped(int row, int col) {
    setState(() {
      _grid[row][col] = _selectedPiece;
      _updateFenText();
    });
  }

  void _clearBoard() {
    setState(() {
      _initGrid();
      _castleK = _castleQ = _castlek = _castleq = false;
      _updateFenText();
    });
  }

  void _startPosition() {
    setState(() {
      _loadFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2b2b2b),
      insetPadding: const EdgeInsets.all(10),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "🧩 Editor Posizione",
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),

              // LA SCACCHIERA INTERATTIVA
              AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                        ),
                    itemCount: 64,
                    itemBuilder: (context, index) {
                      int row = index ~/ 8;
                      int col = index % 8;
                      bool isLight = (row + col) % 2 == 0;
                      Color bgColor = isLight
                          ? const Color(0xFFf0d9b5)
                          : const Color(0xFFb58863);

                      return GestureDetector(
                        onTap: () => _onSquareTapped(row, col),
                        child: Container(
                          color: bgColor,
                          child: Center(
                            child: Text(
                              _symbols[_grid[row][col]]!,
                              style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.width * 0.08,
                                color: Colors.black,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // LA TAVOLOZZA DEI PEZZI
              const Text(
                "Seleziona Pezzo:",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                alignment: WrapAlignment.center,
                children:
                    [
                      'K',
                      'Q',
                      'R',
                      'B',
                      'N',
                      'P',
                      'k',
                      'q',
                      'r',
                      'b',
                      'n',
                      'p',
                      '.',
                    ].map((p) {
                      bool isSelected = _selectedPiece == p;
                      return ChoiceChip(
                        label: Text(
                          p == '.' ? '🗑️' : _symbols[p]!,
                          style: const TextStyle(
                            fontSize: 22,
                            color: Colors.black,
                            height: 1.2,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: Colors.greenAccent,
                        backgroundColor: Colors.white60,
                        onSelected: (_) => setState(() => _selectedPiece = p),
                      );
                    }).toList(),
              ),
              const Divider(color: Colors.white24, height: 20),

              // CONTROLLI AGGIUNTIVI
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _clearBoard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                    ),
                    child: const Text(
                      "Svuota",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _startPosition,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                    ),
                    child: const Text(
                      "Iniziale",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const Text("Turno:", style: TextStyle(color: Colors.white)),
                  Switch(
                    value: _isWhiteTurn,
                    activeThumbColor: Colors.white,
                    inactiveThumbColor: Colors.black,
                    inactiveTrackColor: Colors.grey,
                    onChanged: (val) {
                      setState(() {
                        _isWhiteTurn = val;
                        _updateFenText();
                      });
                    },
                  ),
                  Text(
                    _isWhiteTurn ? "Bianco" : "Nero",
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                ],
              ),

              TextField(
                controller: _fenController,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                decoration: const InputDecoration(
                  labelText: "Stringa FEN",
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyanAccent),
                  ),
                ),
                onChanged: (val) => _loadFen(val),
              ),
              const SizedBox(height: 15),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Annulla",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, _fenController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan[700],
                    ),
                    child: const Text(
                      "APPLICA POSIZIONE",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
