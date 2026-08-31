#[derive(Debug, Clone, Copy, PartialEq)]
pub(crate) enum EncoderFamily {
    Software,
    Nvenc,
    Qsv,
    Vaapi,
    Amf,
    Vulkan,
}

#[derive(Debug, Clone, serde::Serialize)]
pub(crate) struct EncoderCapabilities {
    pub(crate) presets: Option<Vec<String>>,
    pub(crate) tunes: Option<Vec<String>>,
    pub(crate) pix_fmts: Option<Vec<String>>,
    pub(crate) uses_preset: bool,
    pub(crate) uses_tune: bool,
    pub(crate) uses_compression_level: bool,
    pub(crate) crf_flag: String,
    pub(crate) rc_flag: Option<String>,
}
