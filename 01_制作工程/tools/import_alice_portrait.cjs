const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const project = path.resolve(__dirname, "..");
const source = path.resolve(project, "../00_用户素材/选人候选/ALICE_Fiction/000660_经典初音");
const output = path.join(project, "Godot/Miku_Hcxmmx/Portrait/Assets");
const stageSource = path.resolve(project, "../00_用户素材/选人候选/ALICE_Fiction/电子舞台7396");
const stageOutput = path.join(output, "Stage");
fs.mkdirSync(stageOutput, { recursive: true });
for (const file of fs.readdirSync(stageSource).filter(name => name.endsWith(".png"))) {
    fs.copyFileSync(path.join(stageSource, file), path.join(stageOutput, file));
}
const context = vm.createContext({ console });
vm.runInContext(fs.readFileSync(path.join(__dirname, "vendor/spine38/spine-core.js"), "utf8"), context);
const spine = context.spine;
const sourceData = JSON.parse(fs.readFileSync(path.join(source, "actor_000660.json"), "utf8").replace(/^\uFEFF/, ""));
const atlas = new spine.TextureAtlas(fs.readFileSync(path.join(source, "actor_000660.atlas"), "utf8"), () => ({
    setFilters() {},
    setWraps() {},
    getImage() { return { width: 2048, height: 2048 }; }
}));
const loader = new spine.SkeletonJson(new spine.AtlasAttachmentLoader(atlas));
const data = loader.readSkeletonData(sourceData);
const skeleton = new spine.Skeleton(data);
const clipper = new spine.SkeletonClipping();
const fps = 30;
const quad = [0, 1, 2, 2, 3, 0];
const poses = [
    ["normal", "自然"], ["fun", "开心"], ["sing", "歌唱"], ["wonder", "惊讶"],
    ["trouble", "困扰"], ["determination", "认真"], ["neta_a", "趣味 A"], ["neta_b", "趣味 B"]
];
fs.mkdirSync(output, { recursive: true });
fs.copyFileSync(path.join(source, "actor_000660.png"), path.join(output, "actor_000660.png"));
const importPath = path.join(output, "actor_000660.png.import");
if (fs.existsSync(importPath)) {
    const settings = fs.readFileSync(importPath, "utf8")
        .replace(/process\/fix_alpha_border=(true|false)/, "process/fix_alpha_border=false");
    fs.writeFileSync(importPath, settings);
} else {
    fs.writeFileSync(importPath, '[remap]\nimporter="texture"\n\n[params]\nprocess/fix_alpha_border=false\nprocess/premult_alpha=false\n');
}

function rounded(value) {
    return Math.round(value * 1000000) / 1000000;
}

function layerFor(slot) {
    if (slot.data.name === "body") return "body";
    return slot.data.name.includes("mouth") ? "mouth" : "face";
}

function subdivideBody(draw) {
    const corners = draw.vertices;
    const textureCorners = draw.uv;
    const tint = draw.colors[0];
    const columns = 56;
    const rows = 52;
    function interpolate(values, x, y) {
        return [0, 1].map(axis => rounded(
            values[0][axis] * (1 - x) * (1 - y) + values[3][axis] * x * (1 - y)
            + values[1][axis] * (1 - x) * y + values[2][axis] * x * y
        ));
    }
    draw.vertices = [];
    draw.uv = [];
    draw.colors = [];
    draw.indices = [];
    for (let row = 0; row <= rows; row++) {
        for (let column = 0; column <= columns; column++) {
            draw.vertices.push(interpolate(corners, column / columns, row / rows));
            draw.uv.push(interpolate(textureCorners, column / columns, row / rows));
            draw.colors.push(tint);
            if (row < rows && column < columns) {
                const index = row * (columns + 1) + column;
                const next = index + columns + 1;
                draw.indices.push(index, next, next + 1, next + 1, index + 1, index);
            }
        }
    }
}

function snapshot(layer) {
    const draws = [];
    clipper.clipEnd();
    for (const slot of skeleton.drawOrder) {
        const attachment = slot.getAttachment();
        if (attachment instanceof spine.ClippingAttachment) {
            clipper.clipStart(slot, attachment);
            continue;
        }
        if (!attachment || layerFor(slot) !== layer) {
            clipper.clipEndWithSlot(slot);
            continue;
        }
        let vertices;
        let indices;
        let uvs;
        if (attachment instanceof spine.RegionAttachment) {
            vertices = new Float32Array(8);
            attachment.computeWorldVertices(slot.bone, vertices, 0, 2);
            indices = quad;
            uvs = attachment.uvs;
        } else if (attachment instanceof spine.MeshAttachment) {
            vertices = new Float32Array(attachment.worldVerticesLength);
            attachment.computeWorldVertices(slot, 0, vertices.length, vertices, 0, 2);
            indices = attachment.triangles;
            uvs = attachment.uvs;
        } else {
            clipper.clipEndWithSlot(slot);
            continue;
        }
        const tint = new spine.Color(
            skeleton.color.r * slot.color.r * attachment.color.r,
            skeleton.color.g * slot.color.g * attachment.color.g,
            skeleton.color.b * slot.color.b * attachment.color.b,
            skeleton.color.a * slot.color.a * attachment.color.a
        );
        const draw = { vertices: [], uv: [], colors: [], indices: [], material: 0, slot: slot.data.index };
        if (clipper.isClipping()) {
            clipper.clipTriangles(vertices, vertices.length, indices, indices.length, uvs, tint, new spine.Color(), false);
            const clipped = clipper.clippedVertices;
            for (let index = 0; index < clipped.length; index += 8) {
                draw.vertices.push([rounded(clipped[index]), rounded(-clipped[index + 1])]);
                draw.colors.push(Array.from(clipped.slice(index + 2, index + 6), rounded));
                draw.uv.push([rounded(clipped[index + 6]), rounded(clipped[index + 7])]);
            }
            draw.indices = Array.from(clipper.clippedTriangles);
        } else {
            for (let index = 0; index < vertices.length; index += 2) {
                draw.vertices.push([rounded(vertices[index]), rounded(-vertices[index + 1])]);
                draw.uv.push([rounded(uvs[index]), rounded(uvs[index + 1])]);
                draw.colors.push([tint.r, tint.g, tint.b, tint.a]);
            }
            draw.indices = Array.from(indices);
        }
        if (layer === "body" && draw.vertices.length === 4) subdivideBody(draw);
        if (draw.indices.length && tint.a > 0) draws.push(draw);
        clipper.clipEndWithSlot(slot);
    }
    clipper.clipEnd();
    return draws;
}

const info = {
    fps,
    source: "ALICE Fiction / actor_000660 / Spine 3.8.99",
    texture: "res://Miku_Hcxmmx/Portrait/Assets/actor_000660.png",
    bounds: [sourceData.skeleton.x, -sourceData.skeleton.y - sourceData.skeleton.height,
        sourceData.skeleton.width, sourceData.skeleton.height],
    clips: {},
    poses: {}
};

function exportClip(name, animationNames, layer) {
    const state = new spine.AnimationState(new spine.AnimationStateData(data));
    let duration = 1 / fps;
    animationNames.forEach((animation, track) => {
        const sourceAnimation = data.findAnimation(animation);
        if (!sourceAnimation) throw new Error(`Missing portrait animation ${animation}`);
        duration = Math.max(duration, sourceAnimation.duration);
        state.setAnimation(track, animation, true).mixDuration = 0;
    });
    const count = Math.max(1, Math.ceil(duration * fps - 0.00001));
    const frames = [];
    for (let frame = 0; frame < count; frame++) {
        skeleton.setToSetupPose();
        animationNames.forEach((_, track) => { state.getCurrent(track).trackTime = frame / fps; });
        state.update(0);
        state.apply(skeleton);
        skeleton.updateWorldTransform();
        frames.push(snapshot(layer));
    }
    fs.writeFileSync(path.join(output, `${name}.json`), JSON.stringify({ frames }));
    if (layer === "body") {
        const uv = frames[0][0].uv;
        const minimumU = Math.min(...uv.map(point => point[0]));
        const minimumV = Math.min(...uv.map(point => point[1]));
        info.body_uv = [minimumU, minimumV,
            Math.max(...uv.map(point => point[0])) - minimumU,
            Math.max(...uv.map(point => point[1])) - minimumV];
    }
    info.clips[name] = {
        frames_path: `res://Miku_Hcxmmx/Portrait/Assets/${name}.json`,
        frame_count: count,
        max_draws: Math.max(0, ...frames.map(frame => frame.length))
    };
    return name;
}

exportClip("body", [], "body");
for (const [pose, title] of poses) {
    info.poses[pose] = {
        title,
        face: exportClip(`${pose}_face`, [`eye_${pose}`, `eyebrow_${pose}`], "face"),
        mouth: exportClip(`${pose}_mouth`, [`mouth_${pose}`], "mouth"),
        lip: exportClip(`${pose}_lip`, [`mouth_${pose}_lip`], "mouth")
    };
}
fs.writeFileSync(path.join(output, "portrait.json"), JSON.stringify(info, null, 2));
console.log(`ALICE_PORTRAIT_READY poses=${poses.length} clips=${Object.keys(info.clips).length} fps=${fps}`);
