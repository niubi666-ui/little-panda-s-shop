"""Cycles 节点图小工具（从 lookdev/build_game_arena_v2.py 抽出来共用）：用 Python 表达式搭着色节点，
以及从 Godot 材质 .tres 读参数，让 Blender 对照材质和游戏里的着色器用同一组数值。"""
import re


def godot_parameters(path):
    """shader_parameter values from a Godot material .tres (floats and colours only)."""
    values = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            match = re.match(r"shader_parameter/(\w+) = (.+)", line.strip())
            if not match:
                continue
            name, raw = match.groups()
            colour = re.match(r"Color\(([^)]*)\)", raw)
            if colour:
                values[name] = tuple(float(v) for v in colour.group(1).split(","))[:3]
            else:
                try:
                    values[name] = float(raw)
                except ValueError:
                    pass
    return values


class Graph:
    """Small helper for building shader node trees from Python expressions."""

    def __init__(self, tree):
        self.tree = tree

    def node(self, kind, **settings):
        node = self.tree.nodes.new(kind)
        for key, value in settings.items():
            setattr(node, key, value)
        return node

    def feed(self, socket, value):
        if hasattr(value, "is_output") or hasattr(value, "links"):
            self.tree.links.new(value, socket)
        elif isinstance(value, (tuple, list)):
            socket.default_value = tuple(value) + ((1.0,) if len(value) == 3 and len(socket.default_value) == 4 else ())
        else:
            socket.default_value = value

    def math(self, operation, a, b=None, clamp=False):
        node = self.node("ShaderNodeMath", operation=operation, use_clamp=clamp)
        self.feed(node.inputs[0], a)
        if b is not None:
            self.feed(node.inputs[1], b)
        return node.outputs[0]

    def add(self, a, b):
        return self.math("ADD", a, b)

    def mul(self, a, b):
        return self.math("MULTIPLY", a, b)

    def sub(self, a, b):
        return self.math("SUBTRACT", a, b)

    def smooth(self, value, edge0, edge1, rising=True):
        """Godot smoothstep(edge0, edge1, value); rising=False gives 1 - smoothstep."""
        node = self.node("ShaderNodeMapRange", interpolation_type="SMOOTHSTEP", clamp=True)
        self.feed(node.inputs["Value"], value)
        self.feed(node.inputs["From Min"], edge0)
        self.feed(node.inputs["From Max"], edge1)
        node.inputs["To Min"].default_value = 0.0 if rising else 1.0
        node.inputs["To Max"].default_value = 1.0 if rising else 0.0
        return node.outputs["Result"]

    def vec(self, x, y, z=0.0):
        node = self.node("ShaderNodeCombineXYZ")
        self.feed(node.inputs[0], x)
        self.feed(node.inputs[1], y)
        self.feed(node.inputs[2], z)
        return node.outputs[0]

    def noise(self, x, y, scale, offset):
        tex = self.node("ShaderNodeTexNoise")
        tex.inputs["Detail"].default_value = 0.0
        self.feed(tex.inputs["Vector"], self.vec(self.add(self.mul(x, scale), offset), self.add(self.mul(y, scale), offset)))
        tex.inputs["Scale"].default_value = 1.0
        return tex.outputs["Fac"]

    def image(self, image, x, y, scale, non_color=False):
        tex = self.node("ShaderNodeTexImage", image=image)
        self.feed(tex.inputs["Vector"], self.vec(self.math("DIVIDE", x, scale), self.math("DIVIDE", y, scale)))
        return tex.outputs["Color"]

    def mix(self, a, b, factor, blend="MIX"):
        node = self.node("ShaderNodeMix", data_type="RGBA", blend_type=blend, clamp_result=False)
        self.feed(node.inputs["Factor"], factor)
        self.feed(node.inputs[6], a)
        self.feed(node.inputs[7], b)
        return node.outputs[2]

    def mix_float(self, a, b, factor):
        node = self.node("ShaderNodeMix", data_type="FLOAT")
        self.feed(node.inputs["Factor"], factor)
        self.feed(node.inputs[2], a)
        self.feed(node.inputs[3], b)
        return node.outputs[0]
