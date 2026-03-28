import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ─── CONFIGURE ADMIN UID ────────────────────────────────────────────────────
// Add the Firebase UID of your admin account here.
// You can find this in Firebase Console → Authentication
const List<String> kAdminUids = [
  "YOUR_ADMIN_FIREBASE_UID_HERE", // <-- replace
];
// ────────────────────────────────────────────────────────────────────────────

bool get isAdmin {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  return uid != null && kAdminUids.contains(uid);
}

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return const Scaffold(
        backgroundColor: Color(0xFF060714),
        body: Center(
          child: Text(
            "Access denied",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF060714),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF060714), Color(0xFF0d0d2b), Color(0xFF060714)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // App bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left,
                            color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            "Admin · Orders",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Tabs
                Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.07)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7b2ff7), Color(0xFF4776E6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white38,
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.all(4),
                    tabs: const [
                      Tab(text: "Pending"),
                      Tab(text: "Approved"),
                      Tab(text: "Rejected"),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _OrderList(status: 'pending'),
                      _OrderList(status: 'approved'),
                      _OrderList(status: 'rejected'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final String status;
  const _OrderList({required this.status});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pending_orders')
          .where('status', isEqualTo: status)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white24),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined,
                    color: Colors.white.withOpacity(0.2), size: 48),
                const SizedBox(height: 12),
                Text(
                  "No $status orders",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _OrderCard(
              orderId: doc.id,
              data: data,
            );
          },
        );
      },
    );
  }
}

class _OrderCard extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> data;

  const _OrderCard({required this.orderId, required this.data});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _loading = false;

  Future<void> _updateOrder(String newStatus) async {
    setState(() => _loading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      final orderRef = FirebaseFirestore.instance
          .collection('pending_orders')
          .doc(widget.orderId);

      batch.update(orderRef, {
        'status': newStatus,
        'approved_at': FieldValue.serverTimestamp(),
        'approved_by': FirebaseAuth.instance.currentUser?.uid,
      });

      // If approving, add credits to user
      if (newStatus == 'approved') {
        final userId = widget.data['user_id'] as String?;
        final credits = widget.data['credits'] as int? ?? 0;

        if (userId != null && credits > 0) {
          final userRef = FirebaseFirestore.instance
              .collection('users')
              .doc(userId);

          // Atomic increment
          batch.update(userRef, {
            'credits': FieldValue.increment(credits),
          });
        }
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'approved'
                ? "✓ Credits added to user account"
                : "Order rejected"),
            backgroundColor: newStatus == 'approved'
                ? const Color(0xFF22c55e)
                : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return "—";
    return DateFormat("dd MMM yyyy, HH:mm").format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.data['status'] as String? ?? 'pending';
    final isPending = status == 'pending';
    final method = widget.data['payment_method'] as String? ?? '';
    final isNgn = method == 'ngn';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPending
              ? Colors.amber.withOpacity(0.2)
              : status == 'approved'
                  ? const Color(0xFF22c55e).withOpacity(0.2)
                  : Colors.redAccent.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isNgn
                          ? const Color(0xFF22c55e)
                          : const Color(0xFF26a17b))
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isNgn ? "NGN Transfer" : "USDT",
                  style: TextStyle(
                    color: isNgn
                        ? const Color(0xFF22c55e)
                        : const Color(0xFF26a17b),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: status),
              const Spacer(),
              Text(
                _formatTimestamp(
                    widget.data['created_at'] as Timestamp?),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.25),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reference + user
          _InfoRow(
            label: "Reference",
            value: widget.data['reference'] ?? '—',
            mono: true,
          ),
          _InfoRow(
            label: "User",
            value:
                "${widget.data['user_name'] ?? 'Unknown'} · ${widget.data['user_email'] ?? ''}",
          ),
          _InfoRow(
            label: "Pack",
            value:
                "${widget.data['pack_name'] ?? ''} · ${widget.data['credits']} credits",
          ),
          _InfoRow(
            label: "Amount",
            value: isNgn
                ? "₦${widget.data['amount_ngn']}"
                : "\$${widget.data['amount_usdt']} USDT",
          ),

          // Action buttons (only for pending)
          if (isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _loading ? null : () => _updateOrder('rejected'),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.redAccent.withOpacity(0.2)),
                      ),
                      child: Center(
                        child: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.redAccent,
                                ),
                              )
                            : const Text(
                                "Reject",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _loading ? null : () => _updateOrder('approved'),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: _loading
                            ? null
                            : const LinearGradient(
                                colors: [
                                  Color(0xFF22c55e),
                                  Color(0xFF16a34a)
                                ],
                              ),
                        color: _loading
                            ? Colors.white.withOpacity(0.06)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "Approve & Add Credits",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _InfoRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 12,
                fontFamily: mono ? 'monospace' : null,
                fontWeight: mono ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'approved':
        color = const Color(0xFF22c55e);
        label = "Approved";
        break;
      case 'rejected':
        color = Colors.redAccent;
        label = "Rejected";
        break;
      default:
        color = Colors.amber;
        label = "Pending";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}