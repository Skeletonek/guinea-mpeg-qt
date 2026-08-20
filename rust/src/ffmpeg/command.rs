use crate::ffmpeg::normalize_path;

/// Splits a command line into arguments, honouring single/double quotes and
/// backslash escapes. Unbalanced quotes are tolerated (the remainder of the
/// line becomes a single best-effort token).
pub(crate) fn tokenize(text: &str) -> Vec<String> {
    let mut tokens = Vec::new();
    let mut current = String::new();
    let mut chars = text.chars();
    let mut quote: Option<char> = None;

    while let Some(c) = chars.next() {
        match quote {
            Some(q) => {
                if c == q {
                    quote = None;
                } else if c == '\\' && q == '"' {
                    if let Some(n) = chars.next() {
                        current.push(n);
                    }
                } else {
                    current.push(c);
                }
            }
            None => match c {
                '\'' | '"' => quote = Some(c),
                '\\' => {
                    if let Some(n) = chars.next() {
                        current.push(n);
                    }
                }
                c if c.is_whitespace() => {
                    if !current.is_empty() {
                        tokens.push(std::mem::take(&mut current));
                    }
                }
                _ => current.push(c),
            },
        }
    }
    if !current.is_empty() {
        tokens.push(current);
    }
    tokens
}

/// Builds ffmpeg arguments from a user-written command line. The app-provided
/// values are injected through placeholders:
///   {input}, {output}, {start}, {duration}
/// `-ss {start}` and `-t {duration}` are dropped when their values would be
/// empty (no trim). A leading `ffmpeg` token is stripped.
pub(crate) fn build_custom_command(
    cmd: &str,
    input: &str,
    output: &str,
    start_time: f64,
    end_time: f64,
) -> Vec<String> {
    let mut tokens = tokenize(cmd);
    if tokens
        .first()
        .is_some_and(|t| t.eq_ignore_ascii_case("ffmpeg"))
    {
        tokens.remove(0);
    }

    let input = normalize_path(input);
    let output = normalize_path(output);
    let start = start_time.to_string();
    let duration = format!("{:.3}", end_time - start_time);

    let mut args = Vec::new();
    let mut i = 0;
    while i < tokens.len() {
        let tok = &tokens[i];
        let next = tokens.get(i + 1).map(|s| s.as_str());
        if tok == "-ss" && next == Some("{start}") && start_time <= 0.0 {
            i += 2;
            continue;
        }
        if tok == "-t" && next == Some("{duration}") && end_time <= start_time {
            i += 2;
            continue;
        }
        let resolved = tok
            .replace("{input}", &input)
            .replace("{output}", &output)
            .replace("{start}", &start)
            .replace("{duration}", &duration);
        if !resolved.is_empty() {
            args.push(resolved);
        }
        i += 1;
    }
    args
}
