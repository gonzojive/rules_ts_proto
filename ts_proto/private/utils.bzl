# From skylib pull request.
# https://github.com/bazelbuild/bazel-skylib/pull/44/files
def relative_path(target, start):
    """Returns a relative path to `target` from `start`.

    Args:
      target: path that we want to get relative path to (file or directory).
      start: path to directory from which we are starting.

    Returns:
      string: relative path to `target`.
    """

    def remove_end_slash(x):
        if x.endswith("/"):
            return x.removesuffix("/")
        return x

    t_pieces = remove_end_slash(target).split("/")
    s_pieces = remove_end_slash(start).split("/")
    common_part_len = 0

    for tp, rp in zip(t_pieces, s_pieces):
        if tp == rp:
            common_part_len += 1
        else:
            break

    # If start ends in slash,

    result = [".."] * (len(s_pieces) - common_part_len)
    result += t_pieces[common_part_len:]
    if result[0] != ".." and result[0] != ".":
        result = ["."] + result

    result = "/".join(result) if len(result) > 0 else "."
    return result
