import 'package:flutter/material.dart';

enum MultiScreenType {
  grid2x2,
  top1Bottom3,
  top1Bottom2,
  top2Bottom1,
  left1Right1,
  top1Bottom1
}

class MultiScreenSelectorDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Choose Multi-Screen Layout",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildLayoutItem(context, MultiScreenType.grid2x2, _buildGrid2x2()),
                _buildLayoutItem(context, MultiScreenType.top1Bottom3, _buildTop1Bottom3()),
                _buildLayoutItem(context, MultiScreenType.top1Bottom2, _buildTop1Bottom2()),
                _buildLayoutItem(context, MultiScreenType.top2Bottom1, _buildTop2Bottom1()),
                _buildLayoutItem(context, MultiScreenType.left1Right1, _buildLeft1Right1()),
                _buildLayoutItem(context, MultiScreenType.top1Bottom1, _buildTop1Bottom1()),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutItem(BuildContext context, MultiScreenType type, Widget preview) {
    return InkWell(
      onTap: () {
        Navigator.pop(context, type);
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey, width: 2),
          borderRadius: BorderRadius.circular(4),
          color: Colors.black26,
        ),
        padding: const EdgeInsets.all(4),
        child: preview,
      ),
    );
  }

  Widget _box() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }

  Widget _buildGrid2x2() {
    return Column(
      children: [
        Expanded(child: Row(children: [Expanded(child: _box()), Expanded(child: _box())])),
        Expanded(child: Row(children: [Expanded(child: _box()), Expanded(child: _box())])),
      ],
    );
  }

  Widget _buildTop1Bottom3() {
    return Column(
      children: [
        Expanded(flex: 2, child: _box()),
        Expanded(flex: 1, child: Row(children: [Expanded(child: _box()), Expanded(child: _box()), Expanded(child: _box())])),
      ],
    );
  }

  Widget _buildTop1Bottom2() {
    return Column(
      children: [
        Expanded(flex: 2, child: _box()),
        Expanded(flex: 1, child: Row(children: [Expanded(child: _box()), Expanded(child: _box())])),
      ],
    );
  }

  Widget _buildTop2Bottom1() {
    return Column(
      children: [
        Expanded(flex: 1, child: Row(children: [Expanded(child: _box()), Expanded(child: _box())])),
        Expanded(flex: 2, child: _box()),
      ],
    );
  }

  Widget _buildLeft1Right1() {
    return Row(
      children: [
        Expanded(child: _box()),
        Expanded(child: _box()),
      ],
    );
  }

  Widget _buildTop1Bottom1() {
    return Column(
      children: [
        Expanded(child: _box()),
        Expanded(child: _box()),
      ],
    );
  }
}
