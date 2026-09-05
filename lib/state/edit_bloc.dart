import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/parser/cfg_document.dart';

sealed class EditEvent {}

class DocumentOpened extends EditEvent {
  final CfgDocument doc;
  final String baseline;
  DocumentOpened({required this.doc, required this.baseline});
}

class LineValueChanged extends EditEvent {
  final int index;
  final String value;
  LineValueChanged({required this.index, required this.value});
}

class FullTextChanged extends EditEvent {
  final CfgDocument doc; // 文本模式防抖后由解析器产出
  FullTextChanged(this.doc);
}

class SelectionChanged extends EditEvent {
  final int? index;
  SelectionChanged(this.index);
}

class DocumentSaved extends EditEvent {
  final String newBaseline;
  DocumentSaved(this.newBaseline);
}

class EditState {
  final CfgDocument? doc;
  final String baseline;
  final bool dirty;
  final int? selectedIndex;
  const EditState({
    this.doc,
    this.baseline = '',
    this.dirty = false,
    this.selectedIndex,
  });

  // `selectedIndex` 用闭包传参，以区分「未传」与「显式置 null」。
  EditState copyWith({
    CfgDocument? doc,
    String? baseline,
    bool? dirty,
    int? Function()? selectedIndex,
  }) =>
      EditState(
        doc: doc ?? this.doc,
        baseline: baseline ?? this.baseline,
        dirty: dirty ?? this.dirty,
        selectedIndex:
            selectedIndex != null ? selectedIndex() : this.selectedIndex,
      );
}

class EditBloc extends Bloc<EditEvent, EditState> {
  EditBloc() : super(const EditState()) {
    on<DocumentOpened>(
        (e, em) => em(EditState(
            doc: e.doc, baseline: e.baseline, dirty: false, selectedIndex: null)));
    on<LineValueChanged>((e, em) {
      final doc = state.doc;
      if (doc == null) return;
      final l = doc.lines[e.index];
      if (l is KeyValueLine) l.setNewValue(e.value);
      if (l is CvarLine) l.setNewValue(e.value);
      em(state.copyWith(doc: doc, dirty: true));
    });
    on<FullTextChanged>(
        (e, em) => em(state.copyWith(doc: e.doc, dirty: true)));
    on<SelectionChanged>(
        (e, em) => em(state.copyWith(selectedIndex: () => e.index)));
    on<DocumentSaved>(
        (e, em) => em(state.copyWith(baseline: e.newBaseline, dirty: false)));
  }
}
