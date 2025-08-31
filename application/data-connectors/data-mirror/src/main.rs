use argh::FromArgs;

#[derive(FromArgs)]
/// Data Mirror CLI
struct Cli {
    #[argh(subcommand)]
    command: Commands,
}

#[derive(FromArgs)]
#[argh(subcommand)]
enum Commands {
    Egress(EgressCmd),
    Ingress(IngressCmd),
}

#[derive(FromArgs)]
/// Moving data out
#[argh(subcommand, name = "egress")]
struct EgressCmd {
    /// type of database (defaults to postgres)
    #[argh(option, default = "String::from(\"postgres\")")]
    type_: String,
}

#[derive(FromArgs)]
/// Moving data in
#[argh(subcommand, name = "ingress")]
struct IngressCmd {
    /// type of database (defaults to postgres)
    #[argh(option, default = "String::from(\"postgres\")")]
    type_: String,
}

fn main() {
    let cli: Cli = argh::from_env();
    
    match cli.command {
        Commands::Egress(cmd) => {
            println!("Running egress with type: {}", cmd.type_);
        }
        Commands::Ingress(cmd) => {
            println!("Running ingress with type: {}", cmd.type_);
        }
    }
}