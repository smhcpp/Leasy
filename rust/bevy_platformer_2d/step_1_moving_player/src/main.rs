use bevy::prelude::*;
mod cocou;


fn main() {
    App::new()
        .add_plugins(DefaultPlugins)
        .add_plugins(cocou::CocouPlugin)
        .run();
}
