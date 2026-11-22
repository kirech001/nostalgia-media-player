#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::borrow::Cow;

use tao::{
    dpi::LogicalSize,
    event::{Event, WindowEvent},
    event_loop::{ControlFlow, EventLoopBuilder},
    window::{Fullscreen, ResizeDirection, WindowBuilder},
};
use wry::{
    http::{header::CONTENT_TYPE, Request, Response},
    NewWindowResponse, WebViewBuilder,
};

const INDEX: &[u8] = include_bytes!("../ui/index.html");
const STYLE: &[u8] = include_bytes!("../ui/style.css");
const CONTROLS: &[u8] = include_bytes!("../ui/controls.css");
const SCRIPT: &[u8] = include_bytes!("../ui/app.js");
const NOT_FOUND: &[u8] = b"not found";

enum UserEvent {
    Close,
    Minimize,
    Maximize,
    DragWindow,
    Resize(ResizeDirection),
    ToggleFullscreen,
}

fn serve(_id: wry::WebViewId, request: Request<Vec<u8>>) -> Response<Cow<'static, [u8]>> {
    let path = request.uri().path();
    let (body, mime): (&'static [u8], &'static str) = match path {
        "/" | "/index.html" => (INDEX, "text/html; charset=utf-8"),
        "/style.css" => (STYLE, "text/css; charset=utf-8"),
        "/controls.css" => (CONTROLS, "text/css; charset=utf-8"),
        "/app.js" => (SCRIPT, "text/javascript; charset=utf-8"),
        _ => (NOT_FOUND, "text/plain; charset=utf-8"),
    };

    Response::builder()
        .header(CONTENT_TYPE, mime)
        .header("Cache-Control", "no-store")
        .body(Cow::Borrowed(body))
        .expect("valid response")
}

fn main() -> wry::Result<()> {
    let event_loop = EventLoopBuilder::<UserEvent>::with_user_event().build();
    let proxy = event_loop.create_proxy();

    let window = WindowBuilder::new()
        .with_title("Windows Media Player")
        .with_inner_size(LogicalSize::new(1000.0, 690.0))
        .with_min_inner_size(LogicalSize::new(880.0, 600.0))
        .with_decorations(false)
        .with_resizable(true)
        .build(&event_loop)
        .expect("failed to create window");

    if let Some(monitor) = window.current_monitor() {
        let monitor_size = monitor.size();
        let monitor_pos = monitor.position();
        let win = window.outer_size();
        let x = monitor_pos.x + (monitor_size.width as i32 - win.width as i32).max(0) / 2;
        let y = monitor_pos.y + (monitor_size.height as i32 - win.height as i32).max(0) / 2;
        window.set_outer_position(tao::dpi::PhysicalPosition::new(x, y));
    }

    let mut webview = Some(
        WebViewBuilder::new()
            .with_custom_protocol("wmp".into(), serve)
            .with_url("wmp://localhost/")
            .with_new_window_req_handler(|_url, _features| NewWindowResponse::Deny)
            .with_ipc_handler(move |request| {
                let message = request.body().trim();
                let event = match message {
                    "close" => Some(UserEvent::Close),
                    "minimize" => Some(UserEvent::Minimize),
                    "maximize" => Some(UserEvent::Maximize),
                    "drag_window" => Some(UserEvent::DragWindow),
                    "toggle_fullscreen" => Some(UserEvent::ToggleFullscreen),
                    _ => message.strip_prefix("resize:").and_then(|dir| {
                        Some(UserEvent::Resize(match dir {
                            "n" => ResizeDirection::North,
                            "s" => ResizeDirection::South,
                            "e" => ResizeDirection::East,
                            "w" => ResizeDirection::West,
                            "ne" => ResizeDirection::NorthEast,
                            "nw" => ResizeDirection::NorthWest,
                            "se" => ResizeDirection::SouthEast,
                            "sw" => ResizeDirection::SouthWest,
                            _ => return None,
                        }))
                    }),
                };
                if let Some(event) = event {
                    let _ = proxy.send_event(event);
                }
            })
            .build(&window)?,
    );

    let mut fullscreen = false;

    event_loop.run(move |event, _, control_flow| {
        *control_flow = ControlFlow::Wait;

        match event {
            Event::WindowEvent {
                event: WindowEvent::CloseRequested,
                ..
            } => {
                webview.take();
                *control_flow = ControlFlow::Exit;
            }
            Event::UserEvent(user_event) => match user_event {
                UserEvent::Close => {
                    webview.take();
                    *control_flow = ControlFlow::Exit;
                }
                UserEvent::Minimize => window.set_minimized(true),
                UserEvent::Maximize => window.set_maximized(!window.is_maximized()),
                UserEvent::DragWindow => {
                    let _ = window.drag_window();
                }
                UserEvent::Resize(direction) => {
                    let _ = window.drag_resize_window(direction);
                }
                UserEvent::ToggleFullscreen => {
                    fullscreen = !fullscreen;
                    if fullscreen {
                        window.set_fullscreen(Some(Fullscreen::Borderless(None)));
                    } else {
                        window.set_fullscreen(None);
                    }
                }
            },
            _ => {}
        }
    });
}
