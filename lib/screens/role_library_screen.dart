import 'package:flutter/material.dart';
import '../models/role_definition.dart';
import '../services/game_controller.dart';
import '../services/language_service.dart';

class RoleLibraryScreen extends StatefulWidget {
  const RoleLibraryScreen({super.key});

  @override
  State<RoleLibraryScreen> createState() => _RoleLibraryScreenState();
}

class _RoleLibraryScreenState extends State<RoleLibraryScreen> {
  final GameController _controller = GameController();
  RoleDefinition? _selectedRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          langSvc.t('role_library').toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 1.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Row(
        children: [
          // Left Side: Role List
          Container(
            width: 100,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              border: const Border(right: BorderSide(color: Colors.white12)),
            ),
            child: ListView.builder(
              itemCount: _controller.roleDefinitions.length,
              itemBuilder: (context, index) {
                final role = _controller.roleDefinitions[index];
                final isSelected = _selectedRole?.id == role.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedRole = role),
                  child: Container(
                    height: 90,
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? role.primaryColor : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(role.icon, color: isSelected ? Colors.white : role.secondaryColor, size: 30),
                        const SizedBox(height: 4),
                        Text(
                          langSvc.t(role.name),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Right Side: Role Details
          Expanded(
            child: _selectedRole == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.library_books, size: 80, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text(
                          langSvc.currentLanguage == AppLanguage.vi 
                            ? 'Chọn một vai trò để xem chi tiết' 
                            : 'Select a role to see details',
                          style: const TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: _selectedRole!.primaryColor.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _selectedRole!.primaryColor, width: 2),
                                ),
                                child: Icon(_selectedRole!.icon, size: 60, color: _selectedRole!.secondaryColor),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                langSvc.t(_selectedRole!.name).toUpperCase(),
                                style: TextStyle(
                                  color: _selectedRole!.secondaryColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildDifficultyStars(_selectedRole!.difficulty),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildSectionTitle(langSvc.currentLanguage == AppLanguage.vi ? 'MÔ TẢ' : 'DESCRIPTION'),
                        Text(
                          langSvc.t(_selectedRole!.description),
                          style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        if (_selectedRole!.lore != null) ...[
                          _buildSectionTitle(langSvc.currentLanguage == AppLanguage.vi ? 'TRUYỀN THUYẾT' : 'LORE'),
                          Text(
                            langSvc.t(_selectedRole!.lore!),
                            style: const TextStyle(color: Colors.white54, fontSize: 14, fontStyle: FontStyle.italic, height: 1.4),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (_selectedRole!.tips != null && _selectedRole!.tips!.isNotEmpty) ...[
                          _buildSectionTitle(langSvc.currentLanguage == AppLanguage.vi ? 'MẸO CHIẾN THUẬT' : 'STRATEGY TIPS'),
                          ..._selectedRole!.tips!.map((tip) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    langSvc.t(tip),
                                    style: const TextStyle(color: Colors.white60, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyStars(int difficulty) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return Icon(
          index < difficulty ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 18,
        );
      }),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
          ),
          const SizedBox(height: 4),
          Container(width: 40, height: 2, color: _selectedRole!.primaryColor),
        ],
      ),
    );
  }
}
