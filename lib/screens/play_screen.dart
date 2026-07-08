import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/enums.dart';
import '../models/role_definition.dart';
import '../models/online_player.dart';
import '../models/chat_message.dart';
import '../services/game_controller.dart';
import '../services/language_service.dart';

class PlayScreen extends StatefulWidget {
  final String? roomCode;
  final String? userName;
  final bool isQuickMatch;
  const PlayScreen({super.key, this.roomCode, this.userName, this.isQuickMatch = false});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  late final GameController _controller;
  final TextEditingController _chatController = TextEditingController();
  bool _showChatTab = true;
  bool _isGameOverDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _controller = GameController(
      initialRoomCode: widget.roomCode,
      initialUserName: widget.userName,
    );
    _controller.addListener(_onControllerUpdate);
    
    if (widget.isQuickMatch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.updatePlayerCount(15);
        _controller.startGame();
      });
    }
  }

  void _onControllerUpdate() {
    final gameOverMsg = _controller.checkGameOver();
    if (gameOverMsg.isNotEmpty && mounted && !_isGameOverDialogShowing) {
      _isGameOverDialogShowing = true;
      _showGameOverDialog(_controller.isMyWin(gameOverMsg), gameOverMsg);
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _showGameOverDialog(bool isWin, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(children: [
          Icon(isWin ? Icons.emoji_events : Icons.sentiment_very_dissatisfied, color: isWin ? const Color(0xFFFFD54F) : const Color(0xFFEF5350), size: 28),
          const SizedBox(width: 10),
          Text(isWin ? langSvc.t('victory') : langSvc.t('defeat'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        content: Text(message, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          ElevatedButton(
            onPressed: () async { 
              setState(() => _isGameOverDialogShowing = false); 
              await _controller.leaveRoom();
              if (mounted) {
                final nav = Navigator.of(context);
                nav.popUntil((route) => route.isFirst);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD54F), foregroundColor: Colors.black),
            child: Text(langSvc.t('back_to_menu'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    bool shouldPop = false;
    if (_controller.currentState == PlayState.setup || _controller.currentState == PlayState.lobby) {
      shouldPop = true;
    } else {
      shouldPop = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('${langSvc.t('exit_room')}?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(langSvc.t('developing'), style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(langSvc.t('cancel'), style: const TextStyle(color: Colors.white60))),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828)), child: Text(langSvc.t('exit_room'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ],
        ),
      ) ?? false;
    }

    if (shouldPop) {
      await _controller.leaveRoom();
    }
    return shouldPop;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: langSvc,
      builder: (context, _) {
        final isNight = _controller.currentPhase == GamePhase.night;
        final state = _controller.currentState;
        
        Widget body;
        Widget? bottomBar;

        if (state == PlayState.setup) {
          body = SafeArea(child: _buildSetupView());
        } else if (state == PlayState.lobby) {
          body = SafeArea(child: _buildLobbyView());
        } else if (state == PlayState.roleReveal) {
          body = _buildRoleRevealView();
        } else {
          body = SafeArea(child: _buildOnlinePlayingViewBody());
          bottomBar = _buildBottomOnlineController();
        }
        
        if (state == PlayState.setup || state == PlayState.lobby || state == PlayState.roleReveal) {
          body = Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
              ),
            ),
            child: body,
          );
        }

        final bgColor = isNight ? const Color(0xFF0F172A) : const Color(0xFF9CDCFD);
        
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldPop = await _onWillPop();
            if (shouldPop && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            backgroundColor: (state != PlayState.playing) ? Colors.transparent : bgColor,
            body: body,
            bottomNavigationBar: bottomBar,
          ),
        );
      }
    );
  }

  Widget _buildSetupView() {
    return Column(children: [
      _buildTopBar(langSvc.t('setup_room')),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildUserProfileCard(), const SizedBox(height: 24),
        _buildLobbyPlayerCountCard(), const SizedBox(height: 40),
        Text(langSvc.t('settings') + ':', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(langSvc.t('developing'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ]))),
      Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _controller.createRoom, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0288D1)), child: Text(langSvc.t('create_now'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))),
    ]);
  }

  Widget _buildLobbyView() {
    return Column(children: [
      _buildTopBar(langSvc.t('lobby_title'), showInfo: true),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildRoomCodeCard(), const SizedBox(height: 16),
        _buildConnectedPlayersSimulator(), const SizedBox(height: 16),
        _buildChatLogTabs(),
      ]))),
      _buildLobbyBottomBar(),
    ]);
  }

  Widget _buildRoomCodeCard() {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: _controller.roomCode));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${langSvc.t('room_code_label')} ${_controller.roomCode} ${langSvc.currentLanguage == AppLanguage.vi ? "đã được sao chép!" : "copied to clipboard!"}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF0288D1),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16), 
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2), 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: Colors.white30)
        ), 
        child: Row(
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(langSvc.t('room_code_label'), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(_controller.roomCode, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5))),
            ])),
            const SizedBox(width: 12),
            const Icon(Icons.copy, color: Colors.white70, size: 20),
          ]
        )
      ),
    );
  }

  Widget _buildUserProfileCard() {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white30)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(langSvc.t('your_name'), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      TextField(maxLength: 16, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), decoration: InputDecoration(counterText: '', filled: true, fillColor: Colors.white.withValues(alpha: 0.1), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.person, color: Colors.white70)), controller: TextEditingController(text: _controller.userName)..selection = TextSelection.collapsed(offset: _controller.userName.length), onChanged: _controller.updateUserName),
    ]));
  }

  Widget _buildLobbyPlayerCountCard() {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white30)), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(langSvc.t('player_count'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text('${_controller.playerCount} ${langSvc.t('players')}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ]),
      Slider(
        value: _controller.playerCount.toDouble(), 
        min: 9, 
        max: 18, 
        divisions: 9, 
        activeColor: Colors.white, 
        inactiveColor: Colors.white30, 
        onChanged: (v) => _controller.updatePlayerCount(v.toInt())
      ),
    ]));
  }

  Widget _buildConnectedPlayersSimulator() {
    final players = _controller.lobbyPlayerNames;
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white30)), child: Column(children: [
      Row(children: [
        if (players.length < _controller.playerCount) ...[
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 12),
        ],
        Expanded(child: Text(
          players.length < _controller.playerCount 
            ? '${langSvc.t('waiting_players')} (${players.length} / ${_controller.playerCount})'
            : '${langSvc.t('room_full')} (${players.length} / ${_controller.playerCount})', 
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)
        )),
      ]),
      const Divider(color: Colors.white24, height: 20),
      ListView.builder(
        shrinkWrap: true, 
        physics: const NeverScrollableScrollPhysics(), 
        itemCount: players.length, 
        itemBuilder: (c, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4), 
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 10, 
                  backgroundColor: i == 0 ? const Color(0xFFFFD54F) : Colors.white24, 
                  child: Text('${i + 1}', style: TextStyle(fontSize: 9, color: i == 0 ? Colors.black : Colors.white))
                ), 
                const SizedBox(width: 10), 
                Text(
                  players[i], 
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: 13, 
                    fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal
                  )
                ),
                if (i == 0) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.star, color: Color(0xFFFFD54F), size: 12),
                ]
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), 
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2), 
                  borderRadius: BorderRadius.circular(6), 
                  border: Border.all(color: Colors.white54, width: 0.5)
                ), 
                child: Text(i == 0 ? langSvc.t('host') : langSvc.t('ready'), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))
              ),
            ]
          )
        )
      ),
    ]));
  }

  Widget _buildLobbyBottomBar() {
    final isHost = _controller.lobbyPlayerNames.isNotEmpty && _controller.lobbyPlayerNames[0] == _controller.userName;
    return Container(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
      onPressed: isHost ? _controller.startGame : null, 
      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0288D1)), 
      child: Text(isHost ? langSvc.t('start_game') : langSvc.t('waiting_host'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
    )));
  }

  Widget _buildRoleRevealView() {
    final role = _controller.myPlayer?.role;
    if (role == null) return const SizedBox.shrink();

    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              langSvc.t('role_reveal_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              width: 240,
              height: 340,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(role.icon, size: 100, color: role.primaryColor),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      langSvc.t(role.name).toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: role.primaryColor,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      langSvc.t(role.description),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              langSvc.t('preparing_night'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlinePlayingViewBody() {
    return Column(children: [
      _buildOnlinePlayTopBar(),
      _buildOnlinePhaseHeader(),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.all(12), 
          itemCount: _controller.players.length, 
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, 
            crossAxisSpacing: 8, 
            mainAxisSpacing: 8, 
            childAspectRatio: 0.8
          ), 
          itemBuilder: (c, i) => _buildPlayerOnlineCard(_controller.players[i])
        )
      ),
      _buildChatLogTabs(),
    ]);
  }

  Widget _buildOnlinePlayTopBar() {
    final isNight = _controller.currentPhase == GamePhase.night;
    final textColor = isNight ? Colors.white70 : const Color(0xFF0F172A);
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(onPressed: () async { 
        if (await _onWillPop()) {
          _controller.resetGame();
        } 
      }, icon: Icon(Icons.arrow_back_ios_new, color: isNight ? Colors.white : const Color(0xFF0F172A))),
      Column(children: [Text(langSvc.t('room_code_label') + ' ${_controller.roomCode}', style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)), if (_controller.phaseTimerSeconds > 0) Text('Còn lại: ${_controller.phaseTimerSeconds}s', style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 10, fontWeight: FontWeight.bold))]),
      IconButton(onPressed: _showOnlineRulesDialog, icon: const Icon(Icons.help_outline, color: Color(0xFFFFD54F))),
    ]));
  }

  Widget _buildOnlinePhaseHeader() {
    final phase = _controller.currentPhase;
    final isNight = phase == GamePhase.night; 
    final isVoting = phase == GamePhase.voting;
    String phaseTxt = isNight ? langSvc.t('night_phase') : (isVoting ? langSvc.t('voting_phase') : langSvc.t('day_phase'));
    String numTxt = isNight ? '${langSvc.t('night_number')} ${_controller.dayNumber}' : '${langSvc.t('day_number')} ${_controller.dayNumber}';
    String txt = '$phaseTxt - $numTxt';
    Color clr = isNight ? const Color(0xFF311B92) : (isVoting ? const Color(0xFFC62828) : const Color(0xFFF57F17));
    return Container(width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16), decoration: BoxDecoration(color: clr.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: clr.withValues(alpha: 0.5), width: 1.5)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [Icon(isNight ? Icons.nights_stay : Icons.wb_sunny, color: isNight ? const Color(0xFFB39DDB) : const Color(0xFFFFD54F), size: 20), const SizedBox(width: 8), Text(txt, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13))]),
      Text('${langSvc.t('alive_count')}: ${_controller.players.where((p) => p.isAlive).length}/${_controller.playerCount}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    ]));
  }

  Widget _buildPlayerOnlineCard(OnlinePlayer player) {
    final isNight = _controller.currentPhase == GamePhase.night;
    final isSelected = _controller.selectedPlayer?.id == player.id;
    final reveal = _controller.shouldRevealRole(player);
    final border = isSelected ? const Color(0xFFFFD54F) : _controller.getPlayerBorderColor(player);
    final cardColor = player.isAlive 
        ? (isNight ? const Color(0xFF1E293B) : Colors.white) 
        : (isNight ? const Color(0xFF0F172A).withValues(alpha: 0.6) : Colors.grey[300]);
    final textColor = player.isAlive 
        ? (isNight ? Colors.white : const Color(0xFF0F172A)) 
        : (isNight ? Colors.white30 : Colors.black45);

    return GestureDetector(
      onTap: () { 
        final isNight = _controller.currentPhase == GamePhase.night;
        final isVoting = _controller.currentPhase == GamePhase.voting;
        final my = _controller.myPlayer;

        if (isVoting && player.isAlive && player.id != my?.id) {
          _controller.executeVote(player);
        } else if (isNight && my?.role.team == RoleTeam.werewolf && player.isAlive && player.role.team != RoleTeam.werewolf && player.id != _controller.cursedPlayerId) {
          _controller.executeWerewolfBite(player);
          _controller.selectPlayer(player);
        } else {
          _controller.selectPlayer(isSelected ? null : player);
        } 
      },
      child: Container(decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: isSelected ? 2.5 : 1)), child: Stack(alignment: Alignment.center, children: [
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('P${player.id} - ${player.name}', textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 6),
          Icon(reveal ? player.role.icon : Icons.help_outline, color: player.isAlive && reveal ? player.role.secondaryColor : (isNight ? Colors.white24 : Colors.black12), size: 24),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(langSvc.t(_controller.getPlayerRoleNameDisplay(player)), textAlign: TextAlign.center, style: TextStyle(color: player.isAlive && reveal ? player.role.secondaryColor : (isNight ? Colors.white24 : Colors.black12), fontSize: 10, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ]),
        if (!player.isAlive) Positioned.fill(child: Container(decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(16)), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.close, color: Color(0xFFEF5350)), Text(langSvc.t('died_label'), style: const TextStyle(color: Color(0xFFEF5350), fontSize: 10, fontWeight: FontWeight.bold))])))),
        
        _buildSkillIndicators(player),

        if (player.id == _controller.myPlayer?.id) Positioned(top: 6, left: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: player.role.primaryColor, borderRadius: BorderRadius.circular(4)), child: const Text('BẠN', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))),
        if (player.isHost) Positioned(top: 6, left: player.id == _controller.myPlayer?.id ? 30 : 6, child: const Icon(Icons.star, color: Colors.amber, size: 10)),
      ])),
    );
  }

  Widget _buildSkillIndicators(OnlinePlayer player) {
    final my = _controller.myPlayer; 
    if (my == null) {
      return const SizedBox.shrink();
    }
    List<Widget> icons = [];

    // Mắt soi của Tiên Tri
    if (player.hasBeenScannedBySeer && player.id != my.id) {
      icons.add(_miniIcon(Icons.remove_red_eye, Colors.cyan));
    }
    
    // Trái tim của Cupid
    bool isSelectedByCupid = my.role.id == 'cupid' && _controller.cupidSelections.any((p) => p.id == player.id);
    if (_controller.shouldShowLoverHeart(player) || isSelectedByCupid) {
      icons.add(_miniIcon(Icons.favorite, Colors.pink));
    }

    // Khiên của Bảo Vệ
    if (my.role.id == 'bao_ve' && player.wasProtectedByBodyguard) {
      icons.add(_miniIcon(Icons.shield, Colors.blueAccent));
    }

    // Bình Cứu của Phù Thủy (💚)
    if (my.role.id == 'phu_thuy' && player.wasHealedByWitch) {
      icons.add(_miniIcon(Icons.favorite, Colors.greenAccent));
    }

    // Bình Độc của Phù Thủy (🧪)
    if (my.role.id == 'phu_thuy' && player.isPoisoned) {
      icons.add(_miniIcon(Icons.science, Colors.purpleAccent));
    }

    // Lời nguyền của Sói Nguyền
    if (my.role.id == 'soi_nguyen' && _controller.cursedPlayerId == player.id) {
      icons.add(_miniIcon(Icons.auto_awesome, Colors.purpleAccent));
    }

    if (icons.isEmpty && player.voteCount == 0) {
      return const SizedBox.shrink();
    }
    
    final showVotes = _controller.currentPhase != GamePhase.night || my.role.team == RoleTeam.werewolf;

    return Positioned(
      top: 6,
      right: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (icons.isNotEmpty) Wrap(spacing: 2, children: icons),
          if (player.voteCount > 0 && showVotes) Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(6)), child: Text('${player.voteCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _miniIcon(IconData icon, Color clr) => Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: clr, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 2, spreadRadius: 1)]), child: Icon(icon, color: Colors.white, size: 12));

  Widget _buildChatLogTabs() {
    final my = _controller.myPlayer;
    final isWolf = my?.role.team == RoleTeam.werewolf;
    final isLobby = _controller.currentState == PlayState.lobby;
    final isNight = _controller.currentPhase == GamePhase.night;
    final isDark = isLobby || isNight;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isLobby ? 0 : 12, vertical: 4), 
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isLobby ? Colors.white.withValues(alpha: 0.2) : (isDark ? const Color(0xFF0F172A) : Colors.white), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: isLobby ? Colors.white30 : const Color(0xFF334155), width: 0.5), 
        boxShadow: [if (!isDark && !isLobby) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, spreadRadius: 2)]
      ), 
      child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [_buildTabButton(langSvc.t('chat_tab'), isActive: _showChatTab, onTap: () => setState(() => _showChatTab = true)), _buildTabButton(langSvc.t('log_tab'), isActive: !_showChatTab, onTap: () => setState(() => _showChatTab = false))]),
      const Divider(color: Color(0xFF334155), height: 1),
      Container(height: 120, padding: const EdgeInsets.all(8), child: _showChatTab ? ListView.builder(itemCount: _controller.chatMessages.length, itemBuilder: (c, i) {
        final msg = _controller.chatMessages[i]; 
        if (msg.isWerewolfOnly && !(isWolf ?? false)) {
          return const SizedBox.shrink();
        } 
        if (msg.isGhost && my?.isAlive == true) {
          return const SizedBox.shrink();
        }
        return _buildChatMessageTile(msg);
      }) : ListView.builder(itemCount: _controller.actionLogs.length, itemBuilder: (c, i) => _buildActionLogTile(_controller.actionLogs[i]))),
      if (_showChatTab) Padding(padding: const EdgeInsets.all(6), child: Row(children: [
        Expanded(child: SizedBox(height: 38, child: TextField(controller: _chatController, enabled: !_controller.isChatDisabled(), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12), decoration: InputDecoration(hintText: _controller.getChatHintText(), hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black45), filled: true, fillColor: isLobby ? Colors.white.withValues(alpha: 0.1) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)), onSubmitted: (v) { _controller.sendUserMessage(v); _chatController.clear(); }))),
        const SizedBox(width: 6),
        CircleAvatar(radius: 18, backgroundColor: _controller.isChatDisabled() ? Colors.grey : (isLobby ? Colors.white : const Color(0xFFFFD54F)), child: IconButton(icon: Icon(Icons.send, size: 14, color: isLobby ? const Color(0xFF0288D1) : Colors.black), onPressed: _controller.isChatDisabled() ? null : () { _controller.sendUserMessage(_chatController.text); _chatController.clear(); })),
      ])),
    ]));
  }

  Widget _buildChatMessageTile(ChatMessage msg) {
    final isLobby = _controller.currentState == PlayState.lobby;
    final isNight = _controller.currentPhase == GamePhase.night;
    final isDark = isLobby || isNight;
    final isMe = msg.senderName == _controller.userName;
    final displayName = isMe ? '${msg.senderName} (${langSvc.currentLanguage == AppLanguage.vi ? "Bạn" : "You"})' : msg.senderName;
    
    Color clr = msg.isSystem ? (isDark ? const Color(0xFFFFD54F) : const Color(0xFFB45309)) : (msg.isWerewolfOnly ? Colors.red : (msg.isGhost ? Colors.grey : (isMe ? (isDark ? Colors.green : const Color(0xFF15803D)) : (isDark ? Colors.white70 : const Color(0xFF0F172A)))));
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: RichText(text: TextSpan(children: [
      if (msg.isWerewolfOnly) const TextSpan(text: '[SÓI] ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
      if (msg.isGhost) const TextSpan(text: '[MA 👻] ', style: TextStyle(color: Colors.grey, fontSize: 11)),
      TextSpan(text: '$displayName: ', style: TextStyle(color: clr, fontWeight: FontWeight.bold, fontSize: 11.5)),
      TextSpan(text: msg.content, style: TextStyle(color: msg.isGhost ? Colors.grey : (isDark ? Colors.white70 : const Color(0xFF334155)), fontSize: 11.5)),
    ])));
  }

  Widget _buildActionLogTile(String log) {
    final isLobby = _controller.currentState == PlayState.lobby;
    final isNight = _controller.currentPhase == GamePhase.night;
    final isDark = isLobby || isNight;
    
    Color clr = log.startsWith('Hệ thống:') ? (isDark ? const Color(0xFFFFD54F) : const Color(0xFFB45309)) : (log.startsWith('Tiên Tri:') ? (isDark ? Colors.cyan : const Color(0xFF0369A1)) : (log.startsWith('Bảo Vệ:') ? (isDark ? Colors.blue : const Color(0xFF1D4ED8)) : (log.startsWith('Phù Thủy:') ? (isDark ? Colors.purple : const Color(0xFF7E22CE)) : (log.startsWith('Ma Sói:') ? Colors.red : (isDark ? Colors.white70 : const Color(0xFF334155))))));
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(log, style: TextStyle(color: clr, fontSize: 11.5)));
  }

  Widget _buildTabButton(String label, {required bool isActive, required VoidCallback onTap}) {
    final isLobby = _controller.currentState == PlayState.lobby;
    final isNight = _controller.currentPhase == GamePhase.night;
    final isDark = isLobby || isNight;
    
    return Expanded(child: GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 8), alignment: Alignment.center, decoration: BoxDecoration(color: isActive ? Colors.transparent : (isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.05))), child: Text(label, style: TextStyle(color: isActive ? (isDark ? const Color(0xFFFFD54F) : const Color(0xFF0369A1)) : (isDark ? Colors.white60 : Colors.black54), fontSize: 11, fontWeight: FontWeight.bold)))));
  }

  Widget _buildTopBar(String title, {bool showInfo = false}) {
    return Padding(
      padding: const EdgeInsets.all(8), 
      child: Row(children: [
        IconButton(
          onPressed: () async {
            if (await _onWillPop() && context.mounted) {
              Navigator.of(context).pop();
            }
          }, 
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white)
        ), 
        Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center)), 
        showInfo ? IconButton(onPressed: _showOnlineRulesDialog, icon: const Icon(Icons.info_outline, color: Color(0xFFFFD54F))) : const SizedBox(width: 48)
      ])
    );
  }

  void _showOnlineRulesDialog() {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E293B), builder: (c) => Container(padding: const EdgeInsets.all(20), child: ListView.separated(itemCount: _controller.roleDefinitions.length, separatorBuilder: (c, i) => const Divider(color: Colors.white10), itemBuilder: (c, i) => _buildRoleRuleTile(_controller.roleDefinitions[i]))));
  }

  Widget _buildRoleRuleTile(RoleDefinition role) {
    return Row(children: [Icon(role.icon, color: role.secondaryColor), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(langSvc.t(role.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(langSvc.t(role.description), style: const TextStyle(color: Colors.white70, fontSize: 12))]))]);
  }

  Widget _buildBottomOnlineController() {
    final my = _controller.myPlayer;
    if (my == null) return const SizedBox.shrink();
    final isDead = !my.isAlive;
    final isHunterTriggered = _controller.hunterSkillTriggered;
    final isNight = _controller.currentPhase == GamePhase.night; 
    
    final barColor = isNight ? const Color(0xFF1E293B) : const Color(0xFF0369A1);
    
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: barColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        _buildMyRoleSummaryTile(), 
        const SizedBox(width: 8), 
        Expanded(child: Text(
          isHunterTriggered ? langSvc.t('instruction_hunter') : (isDead ? langSvc.t('you_died') : _controller.getActionInstructionText()), 
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), 
          textAlign: TextAlign.center
        ))
      ]),
      const SizedBox(height: 10),
      Row(children: [
        if (isDead && !isHunterTriggered) ...[
          Expanded(child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red), 
            child: Text(langSvc.t('exit_room'), style: const TextStyle(color: Colors.white))
          )),
        ],
        
        if ((!isDead || isHunterTriggered) && _controller.selectedPlayer != null) ...[
          Expanded(child: _buildSkillActionButton()),
        ],
      ]),
    ]));
  }

  Widget _buildMyRoleSummaryTile() {
    final role = _controller.myPlayer!.role;
    return GestureDetector(onTap: _showMyRoleDetailsBottomSheet, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: role.primaryColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.4))), child: Row(children: [Icon(role.icon, color: Colors.white, size: 20), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(langSvc.t('profile') + ':', style: const TextStyle(color: Colors.white70, fontSize: 9)), Text(langSvc.t(role.name), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))]), const SizedBox(width: 4), const Icon(Icons.info_outline, color: Colors.white, size: 14)])));
  }

  Widget _buildSkillActionButton() {
    final target = _controller.selectedPlayer; 
    final my = _controller.myPlayer; 
    if (target == null || my == null) return const SizedBox.shrink();

    final isNight = _controller.currentPhase == GamePhase.night;
    
    if (_controller.hunterSkillTriggered) {
      return Row(children: [
        Expanded(child: ElevatedButton(onPressed: () => _controller.executeHunterShot(target), style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, padding: EdgeInsets.zero), child: FittedBox(child: Text(langSvc.t('action_hunter_shot'), style: const TextStyle(color: Colors.white))))),
      ]);
    }

    if (isNight) {
      if (my.role.id == 'cupid' && _controller.lover1 == null) {
        final sel = _controller.cupidSelections.any((p) => p.id == target.id);
        if (_controller.cupidSelections.length < 2 || sel) {
          return Row(children: [
            Expanded(child: ElevatedButton(onPressed: () => setState(() { 
              if (sel) {
                _controller.cupidSelections.removeWhere((p) => p.id == target.id); 
              } else {
                _controller.cupidSelections.add(target); 
              }
            }), style: ElevatedButton.styleFrom(backgroundColor: sel ? Colors.grey : Colors.pink[300]), child: FittedBox(child: Text(sel ? langSvc.t('action_unselect') : '${langSvc.t('join')} (${_controller.cupidSelections.length}/2)', style: const TextStyle(color: Colors.white))))),
          ]);
        }
        return Row(children: [
          Expanded(child: ElevatedButton(onPressed: _controller.executeCupidLink, style: ElevatedButton.styleFrom(backgroundColor: Colors.pink), child: FittedBox(child: Text(langSvc.t('action_cupid_link'), style: const TextStyle(color: Colors.white))))),
        ]);
      }
      if (my.role.id == 'tien_tri' && !_controller.hasUsedSeerScan && target.isAlive && target.id != my.id && !target.hasBeenScannedBySeer) {
        return Row(children: [
          Expanded(child: ElevatedButton(onPressed: () => _controller.executeSeerScan(target), style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan), child: FittedBox(child: Text(langSvc.t('action_seer_scan'), style: const TextStyle(color: Colors.white))))),
        ]);
      }
      if (my.role.id == 'bao_ve') {
        if (_controller.hasUsedBodyguardProtect) {
          return Row(children: [
            Expanded(child: ElevatedButton(onPressed: _controller.cancelBodyguardProtect, style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]), child: FittedBox(child: Text(langSvc.t('action_cancel_guard'), style: const TextStyle(color: Colors.white))))),
          ]);
        }
        if (target.isAlive && target.id != _controller.lastProtectedPlayerId) {
          return Row(children: [
            Expanded(child: ElevatedButton(onPressed: () => _controller.executeBodyguardProtect(target), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), child: FittedBox(child: Text(langSvc.t('action_guard_protect'), style: const TextStyle(color: Colors.white))))),
          ]);
        }
      }
      if (my.role.id == 'phu_thuy') {
        if (_controller.hasUsedHealThisNight || _controller.hasUsedPoisonThisNight) {
          return Row(children: [
            Expanded(child: ElevatedButton(onPressed: _controller.cancelWitchAction, style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]), child: FittedBox(child: Text(langSvc.t('action_cancel_witch'), style: const TextStyle(color: Colors.white))))),
          ]);
        }
        final bite = _controller.werewolfTarget?.id == target.id; 
        final isVillager = target.role.team == RoleTeam.villager;
        final canHeal = _controller.hasHealPotion && (bite || !target.isAlive) && isVillager;
        final canPoison = _controller.hasPoisonPotion && target.isAlive && target.id != my.id;

        if (canHeal && canPoison) {
          return Row(children: [
            Expanded(child: ElevatedButton(onPressed: () => _controller.executeWitchHeal(target), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: EdgeInsets.zero), child: FittedBox(child: Text(langSvc.t('action_witch_save'), style: const TextStyle(color: Colors.white))))),
            const SizedBox(width: 4),
            Expanded(child: ElevatedButton(onPressed: () => _controller.executeWitchPoison(target), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, padding: EdgeInsets.zero), child: FittedBox(child: Text(langSvc.t('action_witch_poison'), style: const TextStyle(color: Colors.white))))),
          ]);
        }
        if (canHeal) {
          return Row(children: [
            Expanded(child: ElevatedButton(onPressed: () => _controller.executeWitchHeal(target), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: FittedBox(child: Text(langSvc.t('action_witch_revive'), style: const TextStyle(color: Colors.white))))),
          ]);
        }
        if (canPoison) {
          return Row(children: [
            Expanded(child: ElevatedButton(onPressed: () => _controller.executeWitchPoison(target), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple), child: FittedBox(child: Text(langSvc.t('action_witch_kill'), style: const TextStyle(color: Colors.white))))),
          ]);
        }
      }
      if (my.role.team == RoleTeam.werewolf) {
        if (_controller.werewolfTarget?.id == target.id) {
          return Row(children: [
            Expanded(child: ElevatedButton(onPressed: _controller.cancelWerewolfBite, style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]), child: FittedBox(child: Text(langSvc.t('action_cancel_bite'), style: const TextStyle(color: Colors.white))))),
          ]);
        }
      }
    } else {
      if (my.role.id == 'soi_nguyen') {
        if (_controller.cursedPlayerId == target.id) {
          return Row(children: [
            Expanded(child: ElevatedButton(onPressed: _controller.cancelCurse, style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]), child: FittedBox(child: Text(langSvc.t('action_cancel_curse'), style: const TextStyle(color: Colors.white))))),
          ]);
        }
        if (_controller.cursedPlayerId == null && target.isAlive && target.role.team != RoleTeam.werewolf) {
          return Row(children: [
            Expanded(child: ElevatedButton(onPressed: () => _controller.executeCurse(target), style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent), child: FittedBox(child: Text(langSvc.t('action_curse'), style: const TextStyle(color: Colors.white))))),
          ]);
        }
      }
      if (my.role.id == 'xa_thu' && _controller.xathuBullets > 0 && target.isAlive && target.id != my.id) {
        return Row(children: [
          Expanded(child: ElevatedButton(onPressed: () => _controller.executeGunnerShoot(target), style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue), child: FittedBox(child: Text(langSvc.t('action_gunner_shoot'), style: const TextStyle(color: Colors.white))))),
        ]);
      }
    }
    return const SizedBox.shrink();
  }

  void _showMyRoleDetailsBottomSheet() {
    final role = _controller.myPlayer!.role;
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E293B), builder: (c) => Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(role.icon, size: 50, color: role.secondaryColor), const SizedBox(height: 16), Text(langSvc.t(role.name).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 16), Text(langSvc.t(role.description), style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center), const SizedBox(height: 24), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.of(context).pop(), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD54F)), child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold))))])));
  }
}
