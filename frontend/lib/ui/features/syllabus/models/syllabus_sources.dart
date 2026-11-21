enum StandardsSource { obec, custom }

typedef SyllabusIndicator = ({
  String code,
  String description,
  List<int> chapters,
});

typedef SyllabusTextbook = ({String title, int pages, List<String> chapters});

const mathayomOneIndicators = <SyllabusIndicator>[
  (
    code: 'ค 1.1 ม.1/1',
    description: 'Understands integers and rational numbers and uses their properties to solve real-life problems.',
    chapters: [1, 4],
  ),
  (
    code: 'ค 1.1 ม.1/2',
    description:
        'Understands and applies properties of positive integer powers.',
    chapters: [3],
  ),
  (
    code: 'ค 2.2 ม.1/1',
    description: 'Uses geometric construction tools to build figures and solve problems.',
    chapters: [2],
  ),
  (
    code: 'ค 2.2 ม.1/2',
    description:
        'Understands relationships between two- and three-dimensional figures.',
    chapters: [5],
  ),
  (
    code: 'ค 1.3 ม.1/1',
    description: 'Uses linear equations in one variable to solve problems.',
    chapters: [],
  ),
];

const mathayomOneTextbooks = <SyllabusTextbook>[
  (
    title: 'Math M.1 Book 1',
    pages: 214,
    chapters: [
      'Integers',
      'Geometric construction',
      'Exponents',
      'Decimals & fractions',
      '2D & 3D figures',
    ],
  ),
  (
    title: 'Mathematics M.1 Foundations',
    pages: 192,
    chapters: [
      'Working with integers',
      'Constructing figures',
      'Powers and exponents',
      'Rational numbers',
      'Plane and solid figures',
    ],
  ),
];
