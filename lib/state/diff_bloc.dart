import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/diff/line_diff.dart';
import 'edit_bloc.dart';

class DiffState {
  final List<DiffRow> rows;
  const DiffState({this.rows = const []});
}

/// 订阅 EditBloc 的每个状态（DocumentOpened / LineValueChanged /
/// FullTextChanged / DocumentSaved 后基线变化），全量重算行级 diff。
class DiffBloc extends Cubit<DiffState> {
  final LineDiff _diff = LineDiff();
  late final StreamSubscription<EditState> _sub;
  DiffBloc({required Stream<EditState> editStream}) : super(const DiffState()) {
    _sub = editStream.listen(_recompute);
  }

  void _recompute(EditState s) {
    final doc = s.doc;
    if (doc == null) return;
    emit(DiffState(rows: _diff.diff(s.baseline, doc.serialize())));
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
