/// Карты кодируются целым числом 0..51: `suit * 13 + (rank - 1)`.
/// Масти: 0 — пики, 1 — червы, 2 — бубны, 3 — трефы.
library;

const int kSpades = 0;
const int kHearts = 1;
const int kDiamonds = 2;
const int kClubs = 3;

int suitOf(int card) => card ~/ 13;

/// Достоинство 1..13 (туз = 1, король = 13).
int rankOf(int card) => card % 13 + 1;

int makeCard(int suit, int rank) => suit * 13 + rank - 1;

bool isRedSuit(int suit) => suit == kHearts || suit == kDiamonds;

bool isRed(int card) => isRedSuit(suitOf(card));

bool isKing(int card) => rankOf(card) == 13;

/// [upper] лежит на [lower] «правильно»: та же масть, на единицу младше.
bool isLink(int lower, int upper) => suitOf(lower) == suitOf(upper) && rankOf(lower) == rankOf(upper) + 1;

const List<String> kSuitSymbols = ['♠', '♥', '♦', '♣'];

const List<String> kSuitNamesGenitive = ['пик', 'червей', 'бубен', 'треф'];

String rankLabel(int rank) {
  switch (rank) {
    case 1:
      return 'A';
    case 11:
      return 'J';
    case 12:
      return 'Q';
    case 13:
      return 'K';
    default:
      return '$rank';
  }
}

/// Подпись карты для текста. U+FE0E — чтобы масть рисовалась символом, а не эмодзи.
String cardLabel(int card) => '${rankLabel(rankOf(card))}${kSuitSymbols[suitOf(card)]}\u{FE0E}';
