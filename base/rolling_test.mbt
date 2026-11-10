// Blackbox tests for the O(n) rolling primitives.

///|
fn[T] r_err_msg(f : () -> T raise @base.TaError) -> String {
  try f() catch {
    e => e.to_string()
  } noraise {
    _ => "no error"
  }
}
