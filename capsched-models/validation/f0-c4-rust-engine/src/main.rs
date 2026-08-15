mod canonical;
mod model;
mod sha256;

fn usage() -> ! {
    eprintln!(
        "usage:\n  f0-c4-rust-engine setup-closure --role PRODUCER|CHECKER\n  \
         f0-c4-rust-engine bounded-prefix --role PRODUCER|CHECKER --source-limit N\n  \
         f0-c4-rust-engine bounded-stats --role PRODUCER|CHECKER --source-limit N\n  \
         f0-c4-rust-engine wf-prefix --role PRODUCER|CHECKER --source-limit N\n  \
         f0-c4-rust-engine trace --role PRODUCER|CHECKER --actions ACTION[,ACTION...]"
    );
    std::process::exit(64);
}

fn main() {
    let arguments: Vec<String> = std::env::args().skip(1).collect();
    match arguments.as_slice() {
        [command, role_flag, role] if command == "setup-closure" && role_flag == "--role" => {
            model::emit_setup_closure(parse_role(role));
        }
        [command, role_flag, role, limit_flag, source_limit]
            if (command == "bounded-prefix"
                || command == "bounded-stats"
                || command == "wf-prefix")
                && role_flag == "--role"
                && limit_flag == "--source-limit" =>
        {
            let role = parse_role(role);
            let source_limit = parse_source_limit(source_limit);
            match command.as_str() {
                "bounded-prefix" => model::emit_bounded_prefix(role, source_limit),
                "bounded-stats" => model::emit_bounded_stats(role, source_limit),
                "wf-prefix" => model::emit_wf_prefix(role, source_limit),
                _ => unreachable!(),
            }
        }
        [command, role_flag, role, actions_flag, actions]
            if command == "trace" && role_flag == "--role" && actions_flag == "--actions" =>
        {
            let action_ids = parse_actions(actions);
            model::emit_trace(parse_role(role), &action_ids);
        }
        _ => usage(),
    }
}

fn parse_role(role: &str) -> &'static str {
    match role {
        "PRODUCER" => "PRODUCER",
        "CHECKER" => "CHECKER",
        _ => usage(),
    }
}

fn parse_source_limit(value: &str) -> usize {
    match value.parse::<usize>() {
        Ok(value) if value > 0 => value,
        _ => usage(),
    }
}

fn parse_actions(value: &str) -> Vec<String> {
    let actions: Vec<String> = value.split(',').map(str::to_owned).collect();
    if actions.is_empty() || actions.iter().any(String::is_empty) {
        usage();
    }
    actions
}
