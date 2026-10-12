// Noise and fallen-petal helpers shared by the court and the grass.

// Sin-free hash: sin() of large arguments is not reliable across GPU drivers.
float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float hash11(float n) { return hash21(vec2(n, n * 0.37 + 1.9)); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

// One layer of scattered petals. Returns vec2(coverage, random tone).
vec2 petal_layer(vec2 p, float cell, float density, float seed) {
	vec2 grid = p / cell;
	vec2 id = floor(grid) + seed;
	float pick = hash21(id);
	if (pick > density) return vec2(0.0);
	vec2 d = fract(grid) - 0.5 - (vec2(hash21(id + 7.1), hash21(id + 13.7)) - 0.5) * 0.5;
	float angle = hash21(id + 3.3) * TAU;
	float c = cos(angle);
	float s = sin(angle);
	d = vec2(c * d.x + s * d.y, -s * d.x + c * d.y);
	d.x *= 1.75;
	float radius = mix(0.17, 0.27, hash21(id + 5.5));
	return vec2(1.0 - smoothstep(radius * 0.65, radius, length(d)), hash21(id + 9.9));
}

// Petals at two sizes; density 0..1.
vec3 apply_petals(vec3 base, vec2 p, float density, vec3 petal_a, vec3 petal_b) {
	vec2 a = petal_layer(p, 0.27, density, 0.0);
	vec2 b = petal_layer(p + 31.7, 0.19, density * 0.7, 17.0);
	vec3 color = mix(base, mix(petal_a, petal_b, a.y), a.x * 0.92);
	return mix(color, mix(petal_a, petal_b, b.y), b.x * 0.92);
}
