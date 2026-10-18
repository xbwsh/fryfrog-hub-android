import 'package:flutter/material.dart';

import '../../core/models/media_models.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../widgets/mini_player.dart';
import '../../widgets/server_image.dart';

/// Album and artist routes keep a compact player visible while their route is
/// above the main shell.
class MusicCollectionScreen extends StatefulWidget {
  const MusicCollectionScreen.album({
    super.key,
    required this.session,
    required this.album,
  }) : artist = null;

  const MusicCollectionScreen.artist({
    super.key,
    required this.session,
    required this.artist,
  }) : album = null;

  final Session session;
  final MusicAlbum? album;
  final MusicArtist? artist;

  @override
  State<MusicCollectionScreen> createState() => _MusicCollectionScreenState();
}

class _MusicCollectionScreenState extends State<MusicCollectionScreen> {
  List<MusicSong> _songs = const [];
  List<MusicAlbum> _albums = const [];
  String? _error;
  bool _loading = true;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    final api = widget.session.api;
    if (api == null) {
      setState(() {
        _error = '未登录';
        _loading = false;
      });
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      if (widget.album case final album?) {
        final songs = await api.fetchMusicAlbumSongs(album.id);
        if (!mounted || version != _loadVersion) return;
        setState(() {
          _songs = songs;
          _albums = const [];
          _loading = false;
        });
      } else if (widget.artist case final artist?) {
        final results = await Future.wait([
          api.fetchMusicArtist(artist.id),
          api.fetchAllMusicSongs(artistId: artist.id),
        ]);
        if (!mounted || version != _loadVersion) return;
        setState(() {
          _albums = (results[0] as MusicArtistDetail).albums;
          _songs = results[1] as List<MusicSong>;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _error = '加载曲目失败：$e';
        _loading = false;
      });
    }
  }

  Future<void> _play(int index) async {
    if (_songs.isEmpty) return;
    try {
      await widget.session.playMusicQueue(_songs, index);
      final error = widget.session.audioController?.error;
      if (mounted && error != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('播放失败：$error')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('播放失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final album = widget.album;
    final artist = widget.artist;
    final title = album?.title ?? artist?.name ?? '音乐';
    final cover = album?.coverPath ?? artist?.coverPath;
    final subtitle = album == null
        ? '歌手 · ${_songs.length} 首歌曲'
        : '${album.artistName ?? '未知歌手'} · ${_songs.length} 首歌曲';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Dimens.spacingXl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: Dimens.spacingLg),
                        FilledButton(onPressed: _load, child: const Text('重试')),
                      ],
                    ),
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        Dimens.spacingLg,
                        Dimens.spacingLg,
                        Dimens.spacingLg,
                        Dimens.spacingLg,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _CollectionHeader(
                            title: title,
                            subtitle: subtitle,
                            coverUrl: cover,
                            session: widget.session,
                            onPlay: _songs.isEmpty ? null : () => _play(0),
                          ),
                          if (_albums.isNotEmpty) ...[
                            const SizedBox(height: Dimens.spacingXl),
                            Text(
                              '专辑',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: Dimens.spacingSm),
                            for (final item in _albums)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: SizedBox.square(
                                  dimension: Dimens.audioCollectionCoverSize,
                                  child: ServerImage(
                                    url: item.coverPath,
                                    session: widget.session,
                                    borderRadius: BorderRadius.circular(
                                      Dimens.radiusSm,
                                    ),
                                  ),
                                ),
                                title: Text(item.title),
                                subtitle: Text(
                                  '${item.year ?? ''} · ${item.trackCount ?? 0} 首',
                                ),
                              ),
                          ],
                          const SizedBox(height: Dimens.spacingXl),
                          Text(
                            '歌曲',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ]),
                      ),
                    ),
                    if (_songs.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text('暂无歌曲')),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          Dimens.spacingLg,
                          0,
                          Dimens.spacingLg,
                          Dimens.audioRouteScrollClearance,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((context, row) {
                            if (row.isOdd) {
                              return Divider(
                                height: 1,
                                indent: Dimens.audioCollectionSeparatorIndent,
                                color: Theme.of(context).dividerColor
                                    .withValues(alpha: 0.35),
                              );
                            }
                            final index = row ~/ 2;
                            final song = _songs[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: SizedBox.square(
                                dimension: Dimens.audioCollectionCoverSize,
                                child: ServerImage(
                                  url: song.coverPath,
                                  session: widget.session,
                                  borderRadius: BorderRadius.circular(
                                    Dimens.radiusSm,
                                  ),
                                ),
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                song.artistName ?? song.albumName ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.play_arrow_rounded),
                              onTap: () => _play(index),
                            );
                          }, childCount: _songs.length * 2 - 1),
                        ),
                      ),
                  ],
                ),
          Positioned(
            left: Dimens.audioRoutePlayerInset,
            right: Dimens.audioRoutePlayerInset,
            bottom: Dimens.audioRoutePlayerInset,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: Dimens.audioRoutePlayerMaxWidth,
                ),
                child: MiniPlayerBar(session: widget.session),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionHeader extends StatelessWidget {
  const _CollectionHeader({
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.session,
    required this.onPlay,
  });

  final String title;
  final String subtitle;
  final String? coverUrl;
  final Session session;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Dimens.spacingLg),
    decoration: BoxDecoration(
      color: AppColors.surface(context),
      borderRadius: BorderRadius.circular(Dimens.radiusLg),
    ),
    child: Row(
      children: [
        SizedBox(
          width: Dimens.posterWidth,
          height: Dimens.posterWidth,
          child: ServerImage(
            url: coverUrl,
            session: session,
            borderRadius: BorderRadius.circular(Dimens.radiusMd),
          ),
        ),
        const SizedBox(width: Dimens.spacingLg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: Dimens.spacingSm),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: Dimens.spacingMd),
              FilledButton.icon(
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('播放全部'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
