import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../widgets/server_image.dart';

/// Music tab mirrors apple MusicView browse modes.
class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key, required this.session});

  final Session session;

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  int _mode = 0;
  static const _modes = ['歌曲', '专辑', '歌手', '歌单'];

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);
    final session = widget.session;

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.all(
                form.isTv ? Dimens.spacingXxl : Dimens.spacingLg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '音乐',
                    style: TextStyle(
                      fontSize: 28 * form.typeScale,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: Dimens.spacingLg),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: GlassSegmentedControl(
                        segments: [
                          for (final label in _modes) GlassSegment(label: label),
                        ],
                        selectedIndex: _mode,
                        onSegmentSelected: (i) => setState(() => _mode = i),
                      ),
                    ),
                  ),
                  const SizedBox(height: Dimens.spacingXl),
                  Expanded(child: _browseBody(session, form)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _browseBody(Session session, DeviceForm form) {
    switch (_mode) {
      case 1:
        return _AlbumGrid(albums: session.albums, form: form);
      case 2:
        return _ArtistGrid(artists: session.artists, form: form);
      case 3:
        return _EmptyMusic(message: '暂无歌单', form: form);
      default:
        return _SongList(albums: session.albums, form: form);
    }
  }
}

class _SongList extends StatelessWidget {
  const _SongList({required this.albums, required this.form});

  final List<MusicAlbum> albums;
  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return _EmptyMusic(message: '暂无歌曲', form: form);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(Dimens.radiusLg),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: Dimens.spacingSm),
        itemCount: albums.length * 2,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          indent: 72,
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
        itemBuilder: (context, i) {
          final album = albums[i ~/ 2];
          final track = (i ~/ 2) + 1;
          return ListTile(
            dense: !form.isTv,
            leading: SizedBox(
              width: 48 * form.posterScale * 0.75,
              height: 48 * form.posterScale * 0.75,
              child: ServerImage(url: album.coverUrl),
            ),
            title: Text(
              '$track. ${album.title}',
              style: TextStyle(
                fontSize: 14 * form.typeScale,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              album.artistName ?? '未知歌手',
              style: TextStyle(fontSize: 12 * form.typeScale),
            ),
            trailing: const Icon(Icons.play_arrow_rounded),
          );
        },
      ),
    );
  }
}

class _AlbumGrid extends StatelessWidget {
  const _AlbumGrid({required this.albums, required this.form});

  final List<MusicAlbum> albums;
  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return _EmptyMusic(message: '暂无专辑', form: form);
    }

    final cols = form.isTv
        ? 6
        : form.isTabletLandscape
            ? 5
            : form.isTabletPortrait
                ? 4
                : 3;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: Dimens.spacingLg,
        crossAxisSpacing: Dimens.spacingLg,
        childAspectRatio: 0.82,
      ),
      itemCount: albums.length,
      itemBuilder: (context, i) {
        final a = albums[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ServerImage(
                url: a.coverUrl,
                borderRadius: BorderRadius.circular(Dimens.radiusMd),
              ),
            ),
            const SizedBox(height: Dimens.spacingXs),
            Text(
              a.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13 * form.typeScale,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              a.artistName ?? '未知歌手',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12 * form.typeScale,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ArtistGrid extends StatelessWidget {
  const _ArtistGrid({required this.artists, required this.form});

  final List<MusicArtist> artists;
  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return _EmptyMusic(message: '暂无歌手', form: form);
    }

    final cols = form.isTv
        ? 6
        : form.isTablet
            ? 5
            : 3;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: Dimens.spacingLg,
        crossAxisSpacing: Dimens.spacingLg,
        childAspectRatio: 0.9,
      ),
      itemCount: artists.length,
      itemBuilder: (context, i) {
        final a = artists[i];
        return Column(
          children: [
            Expanded(
              child: ServerImage(
                url: a.coverUrl,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: Dimens.spacingSm),
            Text(
              a.name,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13 * form.typeScale,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyMusic extends StatelessWidget {
  const _EmptyMusic({required this.message, required this.form});

  final String message;
  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: TextStyle(
          fontSize: 15 * form.typeScale,
          color: Theme.of(context).hintColor,
        ),
      ),
    );
  }
}
