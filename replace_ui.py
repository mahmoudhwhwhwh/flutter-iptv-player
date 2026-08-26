import re

with open("user_repo_fresh/lib/main.dart", "r") as f:
    content = f.read()

# I need to find the start of `class MainDashboard extends StatefulWidget`
main_dashboard_start = content.find("class MainDashboard extends StatefulWidget")

# Let's truncate everything from MainDashboard onwards and append the new UI code.
content = content[:main_dashboard_start]

new_ui = """
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IPTVProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF070B19), // Dark background
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Search & Last watched
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: Colors.white54, size: 20),
                              const SizedBox(width: 8),
                              Text("بحث", style: GoogleFonts.cairo(color: Colors.white54, fontSize: 14)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              Text("آخر مشاهدة", style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14)),
                              const SizedBox(width: 8),
                              const Icon(Icons.history, color: Colors.white70, size: 20),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Logo
                    Row(
                      children: [
                        const Icon(Icons.hexagon_outlined, color: Colors.amber, size: 36),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "LIVE",
                              style: GoogleFonts.montserrat(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.0),
                            ),
                            Text(
                              "FOOTBALL",
                              style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, height: 1.0),
                            ),
                            Text(
                              "PREMIUM",
                              style: GoogleFonts.montserrat(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w600, height: 1.0),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Expiration Date
                    Row(
                      children: [
                        Text(
                          "قائمة التشغيل الحالية تنتهي: 23/10/2026",
                          style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 20),
                      ],
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      // Left Big Button (Live Stream)
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () {
                            provider.setTab('live');
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const StreamsListScreen(title: "البث المباشر")));
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E3A8A), Color(0xFF312E81)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.live_tv, size: 100, color: Colors.amberAccent),
                                const SizedBox(height: 24),
                                Text(
                                  "بث مباشر",
                                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "شاهد جميع القنوات\nالبث المباشر",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cairo(color: Colors.white70, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Middle Grid
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  _buildGridItem(
                                    context,
                                    title: "أفلام",
                                    subtitle: "جديد الأفلام",
                                    icon: Icons.movie_creation_outlined,
                                    color: Colors.amber,
                                    onTap: () {
                                      provider.setTab('movie');
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StreamsListScreen(title: "أفلام")));
                                    },
                                  ),
                                  const SizedBox(width: 16),
                                  _buildGridItem(
                                    context,
                                    title: "مسلسلات",
                                    subtitle: "جميع المسلسلات",
                                    icon: Icons.video_library_outlined,
                                    color: Colors.amber,
                                    onTap: () {
                                      provider.setTab('series');
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StreamsListScreen(title: "مسلسلات")));
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: Row(
                                children: [
                                  _buildGridItem(
                                    context,
                                    title: "Sports",
                                    subtitle: "مباريات وقنوات رياضية",
                                    icon: Icons.sports_soccer,
                                    color: Colors.amber,
                                    onTap: () {
                                      provider.setTab('live');
                                      provider.setCategory('custom_pro_1');
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StreamsListScreen(title: "Sports")));
                                    },
                                  ),
                                  const SizedBox(width: 16),
                                  _buildGridItem(
                                    context,
                                    title: "المفضلة",
                                    subtitle: "قنواتك المفضلة",
                                    icon: Icons.favorite,
                                    color: Colors.redAccent,
                                    onTap: () {
                                      provider.setTab('favorites');
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StreamsListScreen(title: "المفضلة")));
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: Row(
                                children: [
                                  _buildGridItem(
                                    context,
                                    title: "آخر مشاهدة",
                                    subtitle: "تابع ما بدأت بمشاهدته",
                                    icon: Icons.history,
                                    color: Colors.amber,
                                    onTap: () {},
                                  ),
                                  const SizedBox(width: 16),
                                  _buildGridItem(
                                    context,
                                    title: "تغيير قائمة التشغيل",
                                    subtitle: "اختر قائمتك المفضلة",
                                    icon: Icons.playlist_play,
                                    color: Colors.amber,
                                    onTap: () {},
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Right Banner (World Cup)
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white10),
                            image: const DecorationImage(
                              image: NetworkImage("https://i.postimg.cc/0j0H3hG7/messi-ronaldo-mbappe.jpg"), // Placeholder or similar image
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                colors: [Colors.black.withOpacity(0.8), Colors.transparent, Colors.black.withOpacity(0.8)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      "جميع مباريات\nكأس العالم\n2026",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.cairo(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.2),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.amber),
                                      ),
                                      child: Text(
                                        "اشتراك VIP بدون تقطيع",
                                        style: GoogleFonts.cairo(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildFeatureIcon("4K UHD", "جودة فائقة", Icons.tv),
                                        _buildFeatureIcon("جميع الأجهزة", "Smart TV - Phone", Icons.devices),
                                        _buildFeatureIcon("بدون تقطيع", "استقرار عالي", Icons.lock_outline),
                                        _buildFeatureIcon("تحديث مستمر", "لجميع القنوات", Icons.update),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.indigo.withOpacity(0.5),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.indigoAccent),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.keyboard_double_arrow_right, color: Colors.indigoAccent),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "اشترك الآن واستمتع بالمشاهدة",
                                                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(Icons.keyboard_double_arrow_left, color: Colors.indigoAccent),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade800,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.wechat, color: Colors.white),
                                              const SizedBox(width: 8),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("للتواصل عبر الواتساب", style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10, height: 1.0)),
                                                  Text("+306997606639", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.0)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Buttons
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    _buildBottomBtn("الإعدادات", Icons.settings),
                    const SizedBox(width: 16),
                    _buildBottomBtn("تحديث", Icons.refresh),
                    const SizedBox(width: 16),
                    _buildBottomBtn("اختبار السرعة", Icons.speed),
                    const SizedBox(width: 16),
                    _buildBottomBtn("الإشعارات", Icons.notifications),
                    const Spacer(),
                    _buildBottomBtn("خروج", Icons.exit_to_app, isExit: true, onTap: () => provider.logout()),
                  ],
                ),
              ),
              
              // Footer
              Padding(
                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("v2.0.0", style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 14)),
                    Row(
                      children: [
                        Text("جودة عالية • بدون تقطيع • تحديث مستمر", style: GoogleFonts.cairo(color: Colors.white54, fontSize: 14)),
                        const SizedBox(width: 8),
                        const Icon(Icons.workspace_premium, color: Colors.amber, size: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131B2F),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 48),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.2),
              ),
              Text(
                subtitle,
                style: GoogleFonts.cairo(color: Colors.white54, fontSize: 12, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureIcon(String top, String bottom, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: Colors.amber, size: 24),
        ),
        const SizedBox(height: 4),
        Text(top, style: GoogleFonts.cairo(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        Text(bottom, style: GoogleFonts.cairo(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _buildBottomBtn(String title, IconData icon, {bool isExit = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF131B2F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isExit ? Colors.red.withOpacity(0.3) : Colors.white10),
        ),
        child: Row(
          children: [
            Text(
              title,
              style: GoogleFonts.cairo(color: isExit ? Colors.redAccent : Colors.white, fontSize: 16),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: isExit ? Colors.redAccent : Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }
}

class StreamsListScreen extends StatefulWidget {
  final String title;

  const StreamsListScreen({
    super.key,
    required this.title,
  });

  @override
  State<StreamsListScreen> createState() => _StreamsListScreenState();
}

class _StreamsListScreenState extends State<StreamsListScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IPTVProvider>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF070B19),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // Header
              Container(
                height: 60,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white10)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Text(
                      "مسلسلات | افلام | بث مباشر | مسكن",
                      style: GoogleFonts.cairo(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      width: 300,
                      height: 36,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          const Icon(Icons.search, color: Colors.white54, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (v) => provider.setSearchQuery(v),
                              style: GoogleFonts.cairo(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: "بحث",
                                hintStyle: GoogleFonts.cairo(color: Colors.white54),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.only(bottom: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.tv, color: Colors.amber),
                    const SizedBox(width: 16),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Categories (Left-most because RTL)
                    Container(
                      width: 250,
                      decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: Colors.white10)),
                      ),
                      child: ListView.builder(
                        itemCount: provider.categories.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildCatItem("الكل", "all", provider);
                          }
                          final cat = provider.categories[index - 1];
                          return _buildCatItem(cat, cat, provider);
                        },
                      ),
                    ),

                    // Streams List
                    Container(
                      width: 300,
                      decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: Colors.white10)),
                      ),
                      child: ListView.builder(
                        itemCount: provider.streams.length,
                        itemBuilder: (context, index) {
                          final stream = provider.streams[index];
                          final isSelected = provider.currentStream?.streamId == stream.streamId;
                          return InkWell(
                            onTap: () => provider.selectStream(stream),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF1E3A8A) : Colors.transparent,
                                border: const Border(bottom: BorderSide(color: Colors.white10)),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    "\${index + 1}",
                                    style: GoogleFonts.cairo(color: Colors.white54, fontSize: 14),
                                  ),
                                  const SizedBox(width: 12),
                                  if (stream.streamIcon.isNotEmpty)
                                    Image.network(stream.streamIcon, width: 30, height: 30, errorBuilder: (_,__,___) => const Icon(Icons.tv, color: Colors.white54, size: 24))
                                  else
                                    const Icon(Icons.tv, color: Colors.white54, size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      stream.name,
                                      style: GoogleFonts.cairo(
                                        color: isSelected ? Colors.amber : Colors.white,
                                        fontSize: 16,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Player / Preview
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: provider.currentStream != null 
                              ? InkWell(
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(stream: provider.currentStream!)));
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      image: DecorationImage(
                                        image: NetworkImage("https://i.postimg.cc/mD8zHjJ6/spacetoon.png"), // A placeholder background
                                        fit: BoxFit.cover,
                                        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.play_circle_fill, size: 80, color: Colors.white),
                                    ),
                                  ),
                                )
                              : const Center(child: Text("اختر قناة للمشاهدة", style: TextStyle(color: Colors.white54))),
                          ),
                          Container(
                            height: 150,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.currentStream?.name ?? "",
                                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    _buildActionBtn("القبض"),
                                    const SizedBox(width: 12),
                                    _buildActionBtn("اضافة الى المفضلة"),
                                    const SizedBox(width: 12),
                                    _buildActionBtn("بحث"),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCatItem(String title, String id, IPTVProvider provider) {
    final isSelected = provider.selectedCategory == id;
    return InkWell(
      onTap: () => provider.setCategory(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A) : Colors.transparent,
          border: const Border(bottom: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.cairo(
                  color: isSelected ? Colors.amber : Colors.white70,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              "6", // Example count
              style: GoogleFonts.cairo(color: Colors.amber, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF005C9E), // Blue button color
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        title,
        style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
      ),
    );
  }
}
"""

with open("user_repo_fresh/lib/main.dart", "w") as f:
    f.write(content + new_ui)
