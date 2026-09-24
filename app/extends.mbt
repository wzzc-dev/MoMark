// Explicit trait-method promotions for this package's types.
//
// The MoonBit toolchain deprecated the implicit promotion of trait methods
// as regular methods (`derive(Eq, Debug, ToJson, ...)` making `x.equal(y)`,
// `x.to_repr()`, ... resolve). Each promotion is declared here explicitly so
// it keeps working, mirroring `moui/core/extends_*.mbt`.

///|
#doc(hidden)
pub extend MarkdownEditorHistoryEntry with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend MarkdownEditorHistoryEntry with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownEditorHistoryEntry with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownEditorFindOptions with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend MarkdownEditorFindOptions with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownEditorFindOptions with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownEditorFontFamily with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend MarkdownEditorFontFamily with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownEditorFontFamily with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownEditorTargetKind with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend MarkdownEditorTargetKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownEditorTargetKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownEditorContextTarget with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend MarkdownEditorContextTarget with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownEditorSettings with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend MarkdownEditorSettings with Debug::{to_repr}

///|
#doc(hidden)
pub extend MarkdownEditorSettings with ToJson::{to_json}

///|
#doc(hidden)
pub extend MarkdownEditorSettings with @json.FromJson::{from_json}
