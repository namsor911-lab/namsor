import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      child: Column(
        children: [
          _buildLogo(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('ຫຼັກ'),
                  _buildNavItem(0, Icons.dashboard, 'ພາບລວມ'),
                  _buildSectionLabel('ບັນຊີ'),
                  _buildNavItem(1, Icons.shopping_cart, 'ບັນຊີລາຍການຊື້ເຄື່ອງ'),
                  _buildNavItem(2, Icons.assignment_outlined, 'ແຜນການຊື້ເຄື່ອງ'),
                  _buildNavItem(3, Icons.receipt_long_outlined, 'ອາກອນລາຍໄດ້'),
                  _buildNavItem(4, Icons.receipt, 'ບັນຊີລາຍການ'),
                  _buildSectionLabel('ລາຍງານ'),
                  _buildNavItem(5, Icons.bar_chart, 'ສະຫຼຸບໄຕຣ໌ມາດ'),
                  _buildNavItem(6, Icons.trending_up, 'ສະຫຼຸບລາຍປີ'),
                  _buildSectionLabel('ລະບົບ'),
                  _buildNavItem(7, Icons.settings, 'ຕັ້ງຄ່າ'),
                  const SizedBox(height: 16),
                  _buildStatusFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF238636), Color(0xFF3FB950)],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(child: Text('⚡', style: TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Nam',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: 'Sor',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3FB950),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Text(
                  'HyDroPower',
                  style: TextStyle(fontSize: 10, color: Color(0xFF484F58)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF484F58),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = selectedIndex == index;
    return InkWell(
      onTap: () => onItemSelected(index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: isSelected ? const Color(0xFF1C2128) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF3FB950) : const Color(0xFF8B949E),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? const Color(0xFF3FB950) : const Color(0xFF8B949E),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF3FB950)),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'ລະບົບທຳງານປົກກະຕິ',
              style: TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
