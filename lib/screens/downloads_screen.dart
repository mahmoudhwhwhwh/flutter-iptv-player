import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist_item.dart';
import '../providers/iptv_provider.dart';
import '../services/app_translations.dart';
import '../services/download_manager.dart';
import 'player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  int _selectedFilter = 0; // 0: All, 1: Movies, 2: Series, 3: Active

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IPTVProvider>(context);
    final lang = provider.appLanguageCode;
    final isRtl = AppTranslations.isRtl(lang);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F14),
        appBar: AppBar(
          backgroundColor: const Color(0xFF14141E),
          elevation: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFA855F7).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.download_for_offline_rounded,
                    color: Color(0xFFA855F7), size: 24),
              ),
              const SizedBox(width: 10),
              Text(
                AppTranslations.get('downloads', lang),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: DownloadManager.instance,
          builder: (context, _) {
            final manager = DownloadManager.instance;
            final allItems = manager.items;

            List<DownloadItem> filteredItems = allItems;
            if (_selectedFilter == 1) {
              filteredItems =
                  allItems.where((i) => i.type == 'movie').toList();
            } else if (_selectedFilter == 2) {
              filteredItems =
                  allItems.where((i) => i.type == 'series').toList();
            } else if (_selectedFilter == 3) {
              filteredItems = allItems
                  .where((i) =>
                      i.status == DownloadStatus.downloading ||
                      i.status == DownloadStatus.pending ||
                      i.status == DownloadStatus.paused)
                  .toList();
            }

            return Column(
              children: [
                // Top Storage and Stats Bar
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E1B4B), Color(0xFF2E1065)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFA855F7).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storage_rounded,
                          color: Color(0xFFD8B4FE), size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${AppTranslations.get('storage_used', lang)}: ${manager.formattedTotalStorageUsed}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${manager.completedItems.length} عنصر مكتمل • ${manager.activeItems.length} قيد التنزيل',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Filter Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildFilterChip('الكل (${allItems.length})', 0),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                          'أفلام (${allItems.where((i) => i.type == 'movie').length})',
                          1),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                          'مسلسلات (${allItems.where((i) => i.type == 'series').length})',
                          2),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                          'نشطة (${manager.activeItems.length})', 3),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // List of Downloads or Empty State
                Expanded(
                  child: filteredItems.isEmpty
                      ? _buildEmptyState(lang)
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildDownloadCard(
                                filteredItems[index], provider, lang);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFA855F7)
              : const Color(0xFF1E1E28),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFA855F7)
                : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String lang) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_download_outlined,
                size: 64,
                color: Color(0xFFA855F7),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppTranslations.get('no_downloads', lang),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppTranslations.get('no_downloads_desc', lang),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadCard(
      DownloadItem item, IPTVProvider provider, String lang) {
    final isDownloading = item.status == DownloadStatus.downloading;
    final isPaused = item.status == DownloadStatus.paused;
    final isCompleted = item.status == DownloadStatus.completed;
    final isFailed = item.status == DownloadStatus.failed;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isCompleted
          ? () => _playOfflineItem(context, item)
          : (isPaused || isFailed
              ? () => DownloadManager.instance.resumeDownload(item.id)
              : null),
      child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF22C55E).withOpacity(0.3)
              : (isDownloading
                  ? const Color(0xFFA855F7).withOpacity(0.4)
                  : Colors.white10),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 70,
                    height: 90,
                    color: Colors.black26,
                    child: item.poster.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.poster,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.movie_creation_rounded,
                              color: Colors.white30,
                              size: 32,
                            ),
                          )
                        : const Icon(
                            Icons.movie_creation_rounded,
                            color: Colors.white30,
                            size: 32,
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.type == 'movie'
                                  ? const Color(0xFF3B82F6).withOpacity(0.2)
                                  : const Color(0xFFEC4899).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.type == 'movie' ? 'فيلم' : 'مسلسل',
                              style: TextStyle(
                                color: item.type == 'movie'
                                    ? const Color(0xFF60A5FA)
                                    : const Color(0xFFF472B6),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (item.category.isNotEmpty)
                            Text(
                              item.category,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontFamily: 'Cairo',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Status Details
                      if (isCompleted)
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF22C55E), size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${AppTranslations.get('downloaded', lang)} • ${item.formattedDownloadedSize}',
                              style: const TextStyle(
                                color: Color(0xFF22C55E),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        )
                      else if (isDownloading)
                        Text(
                          '${item.formattedDownloadedSize} / ${item.formattedTotalSize} • ${item.speed}',
                          style: const TextStyle(
                            color: Color(0xFFA855F7),
                            fontSize: 11,
                            fontFamily: 'Cairo',
                          ),
                        )
                      else if (isPaused)
                        const Text(
                          'متوقف مؤقتاً',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                            fontFamily: 'Cairo',
                          ),
                        )
                      else if (isFailed)
                        const Text(
                          'تعذر التنزيل - اضغط لإعادة المحاولة',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontFamily: 'Cairo',
                          ),
                        ),
                    ],
                  ),
                ),

                // Action Buttons
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCompleted) ...[
                      // Play Button
                      IconButton(
                        tooltip: AppTranslations.get('play', lang),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 22),
                        ),
                        onPressed: () => _playOfflineItem(context, item),
                      ),
                    ] else if (isDownloading) ...[
                      // Pause Button
                      IconButton(
                        tooltip: AppTranslations.get('pause', lang),
                        icon: const Icon(Icons.pause_circle_filled_rounded,
                            color: Color(0xFFA855F7), size: 32),
                        onPressed: () =>
                            DownloadManager.instance.pauseDownload(item.id),
                      ),
                    ] else if (isPaused || isFailed) ...[
                      // Resume Button
                      IconButton(
                        tooltip: AppTranslations.get('resume', lang),
                        icon: const Icon(Icons.play_circle_fill_rounded,
                            color: Color(0xFFA855F7), size: 32),
                        onPressed: () =>
                            DownloadManager.instance.resumeDownload(item.id),
                      ),
                    ],

                    // Delete Button
                    IconButton(
                      tooltip: AppTranslations.get('delete', lang),
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.white38, size: 20),
                      onPressed: () => _confirmDelete(context, item, lang),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Progress Bar for downloading/paused items
          if (!isCompleted)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
              child: LinearProgressIndicator(
                value: item.progress.clamp(0.0, 1.0),
                backgroundColor: Colors.white10,
                color: isFailed
                    ? Colors.redAccent
                    : (isPaused ? Colors.amber : const Color(0xFFA855F7)),
                minHeight: 4,
              ),
            ),
        ],
      ),
      ),
    );
  }

  void _playOfflineItem(BuildContext context, DownloadItem item) {
    final file = File(item.filePath);
    if (!file.existsSync() || file.lengthSync() <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'الملف غير موجود في الجهاز أو غير مكتمل، يرجى إعادة تنزيله.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }

    final localStream = PlaylistItem(
      streamId: item.id,
      name: item.title,
      streamIcon: item.poster,
      categoryId: 'downloads',
      categoryName: item.category,
      url: item.filePath,
      type: 'file', // BetterPlayer file playback
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(stream: localStream),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, DownloadItem item, String lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppTranslations.get('delete', lang),
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo'),
        ),
        content: Text(
          '${AppTranslations.get('delete_confirm', lang)}\n"${item.title}"',
          style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            child: Text(
              AppTranslations.get('cancel', lang),
              style: const TextStyle(color: Colors.white60, fontFamily: 'Cairo'),
            ),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              AppTranslations.get('yes_delete', lang),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo'),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              DownloadManager.instance.deleteDownload(item.id);
            },
          ),
        ],
      ),
    );
  }
}
