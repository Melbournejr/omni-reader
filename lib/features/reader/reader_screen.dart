import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/database/reading_db.dart';
import '../../core/file_engines/zero_clone_engine.dart';

class ReaderScreen extends StatefulWidget {
  final String filePath;
  final String title;

  const ReaderScreen({super.key, required this.filePath, required this.title});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  bool _loading = true;
  bool _isComic = false;
  List<Uint8List> _comicPages = [];
  List<String> _textPages = [];
  int _currentPage = 0;
  double _fontSize = 18.0;
  double _lineHeight = 1.65;
  String _fontFamily = 'default';
  String _bgTheme = 'paper';
  String _readingDirection = 'ltr'; // 'ltr', 'rtl', 'vertical'
  bool _doublePage = false;
  bool _showControls = true;
  late PageController _pageController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initReader();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int get _stepSize => _doublePage ? 2 : 1;

  int get _totalItems => _isComic ? _comicPages.length : _textPages.length;

  int get _totalSpreads => _totalItems == 0 ? 1 : (_totalItems / _stepSize).ceil();

  Future<void> _initReader() async {
    final saved = await ReadingDatabase.instance.getProgress(widget.filePath);
    if (saved != null) {
      _currentPage = saved.currentPage;
      _fontSize = saved.fontSize;
      _lineHeight = saved.lineHeight;
      _fontFamily = saved.fontFamily;
      _bgTheme = saved.bgTheme;
      _readingDirection = saved.readingDirection;
      _doublePage = saved.doublePage;
    }

    if (ZeroCloneFileEngine.isComicContainer(widget.filePath)) {
      _isComic = true;
      _comicPages = await ZeroCloneFileEngine.loadComicPagesInMemory(widget.filePath);
      if (_currentPage >= _comicPages.length) _currentPage = 0;
    } else {
      _isComic = false;
      final raw = await ZeroCloneFileEngine.readTextFileDirect(widget.filePath);
      const chunkSize = 1800;
      _textPages = [
        for (var i = 0; i < raw.length; i += chunkSize)
          raw.substring(i, i + chunkSize > raw.length ? raw.length : i + chunkSize),
      ];
      if (_textPages.isEmpty) _textPages = ['(File trá»‘ng)'];
      if (_currentPage >= _textPages.length) _currentPage = 0;
    }

    final initialSpread = (_currentPage / _stepSize).floor();
    _pageController.dispose();
    _pageController = PageController(initialPage: initialSpread);
    setState(() => _loading = false);
    await _saveProgress();
  }

  Future<void> _saveProgress() async {
    await ReadingDatabase.instance.upsertProgress(
      ReadingProgress(
        filePath: widget.filePath,
        title: widget.title,
        currentPage: _currentPage,
        totalPages: _totalItems == 0 ? 1 : _totalItems,
        fontSize: _fontSize,
        lineHeight: _lineHeight,
        fontFamily: _fontFamily,
        bgTheme: _bgTheme,
        readingDirection: _readingDirection,
        doublePage: _doublePage,
        lastOpened: DateTime.now(),
      ),
    );
  }

  void _goToSpread(int spreadIndex) {
    final maxSpread = _totalSpreads - 1;
    if (maxSpread < 0) return;
    final target = spreadIndex.clamp(0, maxSpread);
    if (_readingDirection != 'vertical' && _pageController.hasClients) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
    setState(() => _currentPage = target * _stepSize);
    _saveProgress();
  }

  void _nextPage() {
    final currentSpread = (_currentPage / _stepSize).floor();
    _goToSpread(currentSpread + 1);
  }

  void _prevPage() {
    final currentSpread = (_currentPage / _stepSize).floor();
    _goToSpread(currentSpread - 1);
  }

  void _handleTap(TapDownDetails details, double width) {
    final dx = details.localPosition.dx;
    if (dx < width * 0.28) {
      _readingDirection == 'rtl' ? _nextPage() : _prevPage();
    } else if (dx > width * 0.72) {
      _readingDirection == 'rtl' ? _prevPage() : _nextPage();
    } else {
      setState(() => _showControls = !_showControls);
    }
  }

  Color _backgroundColor() {
    switch (_bgTheme) {
      case 'sepia':
        return const Color(0xFFF4ECD8);
      case 'gray':
        return const Color(0xFFE6E8EC);
      cX\ÙH	Ù\šÉÎ‚ˆ™]\›ˆÛÛœÝÛÛÜŠ‘ŒLŒLŒLŠNÂˆY˜][‚ˆ™]\›ˆÛÛœÝÛÛÜŠ‘‘QŽQŠNÂˆBˆB‚ˆÛÛÜˆÝ^ÛÛÜŠ
HOˆØ™Õ[YHOH	Ù\šÉÈÈÛÛœÝÛÛÜŠ‘‘L‘L‘LŠHˆÛÛœÝÛÛÜŠ‘ŒQŒŒÌŽ
NÂ‚ˆÝš[™ÏÈÜ™\ÛÛ™Y›Û˜[Z[J
HÂˆÝÚ]Ú
Ù›Û˜[Z[JHÂˆØ\ÙH	ÜÙ\šY‰Î‚ˆ™]\›ˆ	ÑÙ[Ü™ÚXIÎÂˆØ\ÙH	ÜØ[œÉÎ‚ˆ™]\›ˆ	Ð\šX[	ÎÂˆØ\ÙH	Û[Û›ÉÎ‚ˆ™]\›ˆ	Û[Û›ÜÜXÙIÎÂˆY˜][‚ˆ™]\›ˆ[ÂˆBˆB‚ˆ›ÚYÛÜ[”Ù][™ÜÔÚY]

HÂˆÚÝÓ[Ù[›ÝÛTÚY]
ˆÛÛ^ˆÛÛ^ˆ\ÔØÜ›ÛÛÛ›ÛYˆYKˆZ[\Žˆ
Ý
HOˆÝ]Y[Z[\ŠˆZ[\Žˆ
ÝÙ]ÚY]Ý]JHOˆY[™ÊˆY[™ÎˆÛÛœÝYÙR[œÙ]Ë˜[
MŠKˆÚ[ˆÛÛ[[ŠˆXZ[^\ÔÚ^™NˆXZ[^\ÔÚ^™K›Z[‹ˆÜ›ÜÜÐ^\Ð[YÛ›Y[ˆÜ›ÜÜÐ^\Ð[YÛ›Y[œÝ\ˆÚ[™[ŽˆÂˆÛÛœÝ^
	ÐðèH1$xn­Ý˜[™È1$xnãXÉËÝ[Nˆ^Ý[J›ÛÚ^™NˆN›ÛÙZYÚˆ›ÛÙZYÚ˜›Û
JKˆÛÛœÝÚ^™Y›Þ
ZYÚˆLŠKˆÛÛœÝ^
	ÐÚxnà]H1$xnãXÉËÝ[Nˆ^Ý[J›ÛÙZYÚˆ›ÛÙZYÚÍŒ
JKˆÜ˜\
ˆÜXÚ[™ÎˆˆÚ[™[ŽˆÂˆÚÚXÙPÚ\
ˆX™[ˆÛÛœÝ^
	Õ°èZHOˆ8n¨ÚH
ŠIÊKˆÙ[XÝYˆÜ™XY[™Ñ\™XÝ[ÛˆOH	Û‰ËˆÛ”Ù[XÝYˆ
ÊHÂˆÙ]Ý]J

HOˆÜ™XY[™Ñ\™XÝ[ÛˆH	Û‰ÊNÂˆÙ]ÚY]Ý]J

HOˆßJNÂˆÜØ]™T›ÙÜ™\ÜÊ
NÂˆKˆ
KˆÚÚXÙPÚ\
ˆX™[ˆÛÛœÝ^
	Ô8n¨ÚHOˆ°èZH
X[™ØJIÊKˆÙ[XÝYˆÜ™XY[™Ñ\™XÝ[ÛˆOH	Ü	ËˆÛ”Ù[XÝYˆ
ÊHÂˆÙ]Ý]J

HOˆÜ™XY[™Ñ\™XÝ[ÛˆH	Ü	ÊNÂˆÙ]ÚY]Ý]J

HOˆßJNÂˆÜØ]™T›ÙÜ™\ÜÊ
NÂˆKˆ
KˆÚÚXÙPÚ\
ˆX™[ˆÛÛœÝ^
	ÐÝxnæ[ˆ8nãXÉÊKˆÙ[XÝYˆÜ™XY[™Ñ\™XÝ[ÛˆOH	Ý™\XØ[	ËˆÛ”Ù[XÝYˆ
ÊHÂˆÙ]Ý]J

HOˆÜ™XY[™Ñ\™XÝ[ÛˆH	Ý™\XØ[	ÊNÂˆÙ]ÚY]Ý]J

HOˆßJNÂˆÜØ]™T›ÙÜ™\ÜÊ
NÂˆKˆ
KˆKˆ
KˆÛÛœÝÚ^™Y›Þ
ZYÚˆLŠKˆÛÛœÝ^
	Ð¸näH[È˜[™ÉËÝ[Nˆ^Ý[J›ÛÙZYÚˆ›ÛÙZYÚÍŒ
JKˆÜ˜\
ˆÜXÚ[™ÎˆˆÚ[™[ŽˆÂˆÚÚXÙPÚ\
ˆX™[ˆÛÛœÝ^
	ÌH˜[™È1$q¨[‰ÊKˆÙ[XÝYˆWÙÝX›TYÙKˆÛ”Ù[XÝYˆ
ÊHÂˆÙ]Ý]J

HOˆÙÝX›TYÙHH˜[ÙJNÂˆÙ]ÚY]Ý]J

HOˆßJNÂˆÜØ]™T›ÙÜ™\ÜÊ
NÂˆKˆ
KˆÚÚXÙPÚ\
ˆX™[ˆÛÛœÝ^
	Ìˆ˜[™È1$píIÊKˆÙ[XÝYˆÙÝX›TYÙKˆÛ”Ù[XÝYˆ
ÊHÂˆÙ]Ý]J

HOˆÙÝX›TYÙHHYJNÂˆÙ]ÚY]Ý]J

HOˆßJNÂˆÜØ]™T›ÙÜ™\ÜÊ
NÂˆKˆ
KˆKˆ
KˆÛÛœÝÚ^™Y›Þ
ZYÚˆLŠKˆÛÛœÝ^
	ÓpèH¸nà[ˆ˜[™ÈÚxn©^IËÝ[Nˆ^Ý[J›ÛÙZYÚˆ›ÛÙZYÚÍŒ
JKˆÜ˜\
ˆÜXÚ[™ÎˆˆÚ[™[ŽˆÂˆ›Üˆ
š[˜[[ˆÂˆÉÜ\\‰Ë	ÑÚxn©^H¸n«Û™É×KˆÉÜÙ\XIË	Õ°è™ÈÚyáº¥y cÅ©'],
                    ['gray', 'XÃ¡m dá»‹u'],
                    ['dark', 'Ná»n tá»‘i'],
                  ])
                    ChoiceChip(
                      label: Text(t[1]),
                      selected: _bgTheme == t[0],
                      onSelected: (_) {
                        setState(() => _bgTheme = t[0]);
                        setSheetState(() => {});
                        _saveProgress();
                      },
                    ),
                ],
              ),
              if (!_isComic) ...[
                const SizedBox(height: 12),
                const Text('PhÃ´ng chá»¯', style: TextStyle(fontWeight: FontWeight.w600)),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in [
                      ['default', 'Máº·c Ä‘á»‹nh'],
                      ['serif', 'Serif (SÃ¡ch giáº¥y)'],
                      ['sans', 'Sans-Serif'],
                      ['mono', 'Monospace'],
                    ])
                      ChoiceChip(
                        label: Text(f[1]),
                        selected: _fontFamily == f[0],
                        onSelected: (_) {
                          setState(() => _fontFamily = f[0]);
                          setSheetState(() => {});
                          _saveProgress();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Cá»¡ chá»¯: ${_fontSize.toStringAsFixed(0)}pt'),
                Slider(
                  value: _fontSize,
                  min: 13,
                  max: 36,
                  onChanged: (v) {
                    setState(() => _fontSize = v);
                    setSheetState(() => {});
                    _saveProgress();
                  },
                ),
                Text('GiÃ£n dÃ²ng: ${_lineHeight.toStringAsFixed(1)}',
                Slider(
                  value: _lineHeight,
                  min: 1.2,
                  max: 2.2,
                  onChanged: (v) {
                    setState(() => _lineHeight = v);
                    setSheetState(() => {});
                    _saveProgress();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleItem(int index) {
    if (_isComic) {
      return InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        child: Center(child: Image.memory(_comicPages[index], fit: BoxFit.contain)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Text(
          _textPages[index],
          style: TextStyle(
            fontSize: _fontSize,
            height: _lineHeight,
            fontFamily: _resolvedFontFamily(),
            color: _textColor(),
          ),
        ),
      ),
    );
  }

  Widget _buildSpread(int spreadIndex) {
    if (!_doublePage) {
      return _buildSingleItem(spreadIndex);
    }
    final first = spreadIndex * 2;
    final second = first + 1;
    final hasSecond = second < _totalItems;
    final leftIdx = _readingDirection == 'rtl' ? (hasSecond ? second : first) : first;
    final rightIdx = _readingDirection == 'rtl' ? (hasSecond ? first : null) : (hasSecond ? second : null);

    return Row(
      children: [
        Expanded(child: _buildSingleItem(leftIdx)),
        const VerticalDivider(width: 1),
        Expanded(child: rightIdx „ô¹Õ±°€ü}‰Õ¥±‘M¥¹±•%Ñ•´¡É¥¡Ñ%‘à¤€è½¹ÍÐM¥é•‘	½à¹Í¡É¥¹¬ ¤¤°(€€€€€t°(€€€€¤ì(€ô((€½Ù•ÉÉ¥‘”(€]¥‘•Ð‰Õ¥±¡	Õ¥±‘½¹Ñ•áÐ½¹Ñ•áÐ¤ì(€€€™¥¹…°ÕÉÉ•¹ÑMÁÉ•…€ô€¡}ÕÉÉ•¹ÑA…”€¼}ÍÑ•ÁM¥é”¤¹™±½½È ¤¹±…µÀ À°}Ñ½Ñ…±MÁÉ•…‘Ì€´€Ä¤ì((€€€É•ÑÕÉ¸-•å‰½…É‘1¥ÍÑ•¹•È (€€€€€™½ÕÍ9½‘”è}™½ÕÍ9½‘”°(€€€€€…ÕÑ½™½ÕÌèÑÉÕ”°(€€€€€½¹-•åÙ•¹Ðè€¡•Ù•¹Ð¤ì(€€€€€€€¥˜€¡•Ù•¹Ð¥Ì-•å½Ý¹Ù•¹Ð¤ì(€€€€€€€€€™¥¹…°¬€ô•Ù•¹Ð¹±½¥…±-•äì(€€€€€€€€€¥˜€¡¬€ôô1½¥…±-•å‰½…É‘-•ä¹…ÉÉ½ÝI¥¡Ðñð¬€ôô1½¥…±-•å‰½…É‘-•ä¹ÍÁ…”ñð¬€ôô1½¥…±-•å‰½…É‘-•ä¹Á…•½Ý¸¤ì(€€€€€€€€€€€}É•…‘¥¹¥É•Ñ¥½¸€ôô€ÉÑ°œ€ü}ÁÉ•ÙA…” ¤€è}¹•áÑA…” ¤ì(€€€€€€€€€ô•±Í”¥˜€¡¬€ôô1½¥…±-•å‰½…É‘-•ä¹…ÉÉ½Ý1•™Ðñð¬€ôô1½¥…±-•å‰½…É‘-•ä¹Á…•UÀ¤ì(€€€€€€€€€€€}É•…‘¥¹¥É•Ñ¥½¸€ôô€ÉÑ°œ€ü}¹•áÑA…” ¤€è}ÁÉ•ÙA…” ¤ì(€€€€€€€€€ô(€€€€€€€ô(€€€€€ô°(€€€€€¡¥±èM…™™½± (€€€€€€€‰…­É½Õ¹‘½±½Èè}‰…­É½Õ¹‘½±½È ¤°(€€€€€€€…ÁÁ	…Èè}Í¡½Ý½¹ÑÉ½±Ì(€€€€€€€€€€€€üÁÁ	…È (€€€€€€€€€€€€€€€Ñ¥Ñ±”èQ•áÐ¡Ý¥‘•Ð¹Ñ¥Ñ±”¤°(€€€€€€€€€€€€€€€…Ñ¥½¹Ìèl(€€€€€€€€€€€€€€€€€%½¹	ÕÑÑ½¸ (€€€€€€€€€€€€€€€€€€€¥½¸è%½¸¡}‘½Õ‰±•A…”€ü%½¹Ì¹¡½Ù¥•Ý}…•¹‘…}½ÕÑ±¥¹•€è%½¹Ì¹¡É½µ•}É•…‘•É}µ½‘”¤°(€€€€€€€€€€€€€€€€€€€Ñ½½±Ñ¥Àè}‘½Õ‰±•A…”€ü€¡¥•Ô€ÄÑÉ…¹œœ€è€¡¥•Ô€ÈÑÉ…¹œ‘½¤œ°(€€€€€€€€€€€€€€€€€€€½¹AÉ•ÍÍ•è€ ¤ì(€€€€€€€€€€€€€€€€€€€€€Í•ÑMÑ…Ñ”  ¤€ôø}‘½Õ‰±•A…”€ô€…}‘½Õ‰±•A…”¤ì(€€€€€€€€€€€€€€€€€€€€€}Í…Ù•AÉ½É•ÍÌ ¤ì(€€€€€€€€€€€€€€€€€€€ô°(€€€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€€€€%½¹	ÕÑÑ½¸ (€€€€€€€€€€€€€€€€€€€¥½¸è½¹ÍÐ%½¸¡%½¹Ì¹ÑÕ¹”¤°(€€€€€€€€€€€€€€€€€€€Ñ½½±Ñ¥Àè€¤ƒG†êÝÐ™½¹Ð£†î¼°·Ô»†î¸°¡§†îÔƒG†î5Œœ°(€€€€€€€€€€€€€€€€€€€½¹AÉ•ÍÍ•è}½Á•¹M•ÑÑ¥¹ÍM¡••Ð°(€€€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€€t°(€€€€€€€€€€€€€€¤(€€€€€€€€€€€€è¹Õ±°°(€€€€€€€‰½‘äè}±½…‘¥¹œ(€€€€€€€€€€€€ü½¹ÍÐ•¹Ñ•È¡¡¥±è¥ÉÕ±…ÉAÉ½É•ÍÍ%¹‘¥…Ñ½È ¤¤(€€€€€€€€€€€€è1…å½ÕÑ	Õ¥±‘•È (€€€€€€€€€€€€€‰Õ¥±‘•Èè€¡½¹Ñ•áÐ°½¹ÍÑÉ…¥¹ÑÌ¤€ôø•ÍÑÕÉ••Ñ•Ñ½È (€€€€€€€€€€€€€€€‰•¡…Ù¥½Èè!¥ÑQ•ÍÑ	•¡…Ù¥½È¹½Á…ÅÕ”°(€€€€€€€€€€€€€€€½¹…µ…•Q…Á½Ý¸è¹Õ±°°(€€€€€€€€€€€€€€€½µQ…Á½Ý¸è€¡‘•Ñ…¥±Ì¤€ôø}¡…¹‘±•Q…À¡‘•Ñ…¥±Ì°½¹ÍÑÉ…¥¹ÑÌ¹µ…á]¥‘Ñ ¤°(€€€€€€€€€€€€€€€¡¥±è}É•…‘¥¹¥É•Ñ¥½¸€ôô€Ù•ÉÑ¥…°œ(€€€€€€€€€€€€€€€€€€€€ü1¥ÍÑY¥•Ü¹‰Õ¥±‘•È (€€€€€€€€€€€€€€€€€€€€€€€¥Ñ•µ½Õ¹Ðè}Ñ½Ñ…±%Ñ•µÌ°(€€€€€€€€€€€€€€€€€€€€€€€¥Ñ•µ	Õ¥±‘•Èè€¡Ñà°¥‘à¤€ôø}‰Õ¥±‘M¥¹±•%Ñ•´¡¥‘à¤°(€€€€€€€€€€€€€€€€€€€€€€¤(€€€€€€€€€€€€€€€€€€€€èA…•Y¥•Ü¹‰Õ¥±‘•È (€€€€€€€€€€€€€€€€€€€€€€€½¹ÑÉ½±±•Èè}Á…•½¹ÑÉ½±±•È°(€€€€€€€€€€€€€€€€€€€€€€€É•Ù•ÉÍ”è}É•…‘¥¹¥É•Ñ¥½¸€ôô€ÉÑ°œ°(€€€€€€€€€€€€€€€€€€€€€€€¥Ñ•µ½Õ¹Ðè}Ñ½Ñ…±MÁÉ•…‘Ì°(€€€€€€€€€€€€€€€€€€€€€€€½¹A…•¡…¹•è€¡ÍÁÉ•…‘%‘à¥ôì(€€€€€€€€€€€€€€€€€€€€€€€€€Í•ÑMÑ…Ñ”  ¤€ôø}ÕÉÉ•¹ÑA…”€ôÍÁÉ•…‘%‘à€¨}ÍÑ•ÁM¥é”¤ì(€€€€€€€€€€€€€€€€€€€€€€€€€}Í…Ù•AÉ½É•ÍÌ ¤ì(€€€€€€€€€€€€€€€€€€€€€€€ô°(€€€€€€€€€€€€€€€€€€€€€€€¥Ñ•µ	Õ¥±‘•Èè€¡Ñà°ÍÁÉ•…‘%‘à¤€ôø}‰Õ¥±‘MÁÉ•…¡ÍÁÉ•…‘%‘à¤°(€€€€€€€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€€€¤ì(€€€€€€€€€€€€€ô°(€€€€€€€€€€€€¤°(€€€€€€€‰½ÑÑ½µ9…Ù¥…Ñ¥½¹	…Èè}Í¡½Ý½¹ÑÉ½±Ì€˜˜}Ñ½Ñ…±%Ñ•µÌ€ø€À(€€€€€€€€€€€€ü	½ÑÑ½µÁÁ	…È (€€€€€€€€€€€€€€€¡¥±èI½Ü (€€€€€€€€€€€€€€€€€¡¥±‘É•¸èl(€€€€€€€€€€€€€€€€€€€%½¹	ÕÑÑ½¸ (€€€€€€€€€€€€€€€€€€€€€¥½¸è½¹ÍÐ%½¸¡%½¹Ì¹¡•ÙÉ½¹}±•™Ð¤°(€€€€€€€€€€€€€€€€€€€€€½¹AÉ•ÍÍ•è}É•…‘¥¹¥É•Ñ¥½¸€ôô€ÉÑ°œ€ü}¹•áÑA…”€è}ÁÉ•ÙA…”°(€€€€€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€€€€€€Q•áÐ œ‘í}ÕÉÉ•¹ÑA…”€¬€Åô€¼€‘}Ñ½Ñ…±%Ñ•µÌœ¤°(€€€€€€€€€€€€€€€€€€€áÁ…¹‘• (€€€€€€€€€€€€€€€€€€€€€¡¥±èM±¥‘•È (€€€€€€€€€€€€€€€€€€€€€€€Ù…±Õ”èÕÉÉ•¹ÑMÁÉ•…¹Ñ½½Õ‰±” ¤°(€€€€€€€€€€€€€€€€€€€€€€€µ…àè€¡}Ñ½Ñ…±MÁÉ•…‘Ì€´€Ä¤€ø€À€ü€¡}Ñ½Ñ…±MÁÉ•…‘Ì€´€Ä¤¹Ñ½½Õ‰±” ¤€è€Ä°(€€€€€€€€€€€€€€€€€€€€€€€½¹¡…¹•è€¡Ø¤€ôø}½Q½MÁÉ•…¡Ø¹É½Õ¹ ¤¤°(€€€€€€€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€€€€€€%½¹	ÕÑÑ½¸ (€€€€€€€€€€€€€€€€€€€€€¥½¸è½¹ÍÐ%½¸¡%½¹Ì¹¡•ÙÉ½¹}É¥¡Ð¤°(€€€€€€€€€€€€€€€€€€€€€½¹AÉ•ÍÍ•è}É•…‘¥¹¥É•Ñ¥½¸€ôô€ÉÑ°œ€ü}ÁÉ•ÙA…”€è}¹•áÑA…”°(€€€€€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€€€€€€%½¹	ÕÑÑ½¸ (€€€€€€€€€€€€€€€€€€€€€¥½¸è½¹ÍÐ%½¸¡%½¹Ì¹Í•ÑÑ¥¹Í}½ÕÑ±¥¹•¤°(€€€€€€€€€€€€€€€€€€€€€½¹AÉ•ÍÍ•è}½Á•¹M•ÑÑ¥¹ÍM¡••Ð°(€€€€€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€€€€t°(€€€€€€€€€€€€€€€€¤°(€€€€€€€€€€€€€€¤(€€€€€€€€€€€€è¹Õ±°°(€€€€€€¤°(€€€€¤ì(€ô)
