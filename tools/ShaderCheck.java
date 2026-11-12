import static org.lwjgl.glfw.GLFW.*;
import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.opengl.GL20.*;
import static org.lwjgl.opengl.GL43.GL_COMPUTE_SHADER;
import static org.lwjgl.system.MemoryUtil.NULL;

import java.nio.file.*;
import java.util.*;
import org.lwjgl.opengl.GL;

// Compiles and links every program of the shader pack on the real GPU driver.
// Resolves #include and injects the macros Iris would define.
public class ShaderCheck {
    static Path root;
    static String IRIS_DEFINES =
        "#define MC_RENDER_STAGE_SKY 1\n#define MC_RENDER_STAGE_SUNSET 2\n#define MC_RENDER_STAGE_STARS 4\n";
    static int glVersion = 460;

    static String load(Path file, List<String> undef) throws Exception {
        StringBuilder sb = new StringBuilder();
        for (String line : Files.readAllLines(file)) {
            String t = line.trim();
            if (t.startsWith("#include")) {
                String inc = t.substring(t.indexOf('"') + 2, t.lastIndexOf('"'));
                sb.append(load(root.resolve(inc), undef));
                continue;
            }
            boolean skip = false;
            for (String u : undef) if (t.startsWith("#define " + u)) skip = true;
            if (!skip) sb.append(line).append('\n');
            if (t.startsWith("#version")) sb.append(IRIS_DEFINES);
        }
        return sb.toString();
    }

    static int compile(int type, String src, String label) {
        int s = glCreateShader(type);
        glShaderSource(s, src);
        glCompileShader(s);
        String log = glGetShaderInfoLog(s).trim();
        boolean ok = glGetShaderi(s, GL_COMPILE_STATUS) == GL_TRUE;
        if (!ok || !log.isEmpty()) System.out.println((ok ? "  WARN " : "  FAIL ") + label + "\n" + log);
        return ok ? s : 0;
    }

    public static void main(String[] args) throws Exception {
        root = Paths.get(args[0]);
        // Arguments: NAME to leave an option undefined, MC_GL_VERSION=410 to pretend an older driver
        List<String> undef = new ArrayList<>();
        for (String a : Arrays.asList(args).subList(1, args.length)) {
            if (a.startsWith("MC_GL_VERSION=")) glVersion = Integer.parseInt(a.substring(14)); else undef.add(a);
        }
        // Iris defines IRIS_FEATURE_* only for features the driver supports
        if (glVersion >= 430) IRIS_DEFINES += "#define IRIS_FEATURE_CUSTOM_IMAGES\n#define IRIS_FEATURE_COMPUTE_SHADERS\n";

        if (!glfwInit()) throw new IllegalStateException("glfwInit failed");
        glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);
        glfwWindowHint(GLFW_FOCUSED, GLFW_FALSE);
        long window = glfwCreateWindow(64, 64, "shader-check", NULL, NULL);
        if (window == NULL) throw new IllegalStateException("window creation failed");
        glfwMakeContextCurrent(window);
        GL.createCapabilities();
        System.out.println(glGetString(GL_RENDERER) + " | " + glGetString(GL_VERSION) + " | undef=" + undef + " | MC_GL_VERSION=" + glVersion);

        int failed = 0, total = 0;
        try (DirectoryStream<Path> ds = Files.newDirectoryStream(root, "*.vsh")) {
            List<Path> files = new ArrayList<>();
            ds.forEach(files::add);
            Collections.sort(files);
            for (Path vsh : files) {
                String name = vsh.getFileName().toString().replace(".vsh", "");
                total++;
                int vs = compile(GL_VERTEX_SHADER, load(vsh, undef), name + ".vsh");
                int fs = compile(GL_FRAGMENT_SHADER, load(root.resolve(name + ".fsh"), undef), name + ".fsh");
                boolean ok = vs != 0 && fs != 0;
                if (ok) {
                    int p = glCreateProgram();
                    glAttachShader(p, vs);
                    glAttachShader(p, fs);
                    glLinkProgram(p);
                    ok = glGetProgrami(p, GL_LINK_STATUS) == GL_TRUE;
                    String log = glGetProgramInfoLog(p).trim();
                    if (!ok || !log.isEmpty()) System.out.println((ok ? "  WARN " : "  FAIL ") + name + " (link)\n" + log);
                }
                if (!ok) failed++;
                System.out.println((ok ? "ok    " : "FAILED ") + name);
            }
        }
        // Compute programs have a single stage
        try (DirectoryStream<Path> ds = Files.newDirectoryStream(root, "*.csh")) {
            for (Path csh : ds) {
                String name = csh.getFileName().toString();
                if (glVersion < 430) { System.out.println("skip  " + name + " (compute needs OpenGL 4.3)"); continue; }
                total++;
                int cs = compile(GL_COMPUTE_SHADER, load(csh, undef), name);
                boolean ok = cs != 0;
                if (ok) {
                    int p = glCreateProgram();
                    glAttachShader(p, cs);
                    glLinkProgram(p);
                    ok = glGetProgrami(p, GL_LINK_STATUS) == GL_TRUE;
                    String log = glGetProgramInfoLog(p).trim();
                    if (!ok || !log.isEmpty()) System.out.println((ok ? "  WARN " : "  FAIL ") + name + " (link)\n" + log);
                }
                if (!ok) failed++;
                System.out.println((ok ? "ok    " : "FAILED ") + name);
            }
        }
        System.out.println("programs: " + total + ", failed: " + failed);
        glfwDestroyWindow(window);
        glfwTerminate();
        System.exit(failed == 0 ? 0 : 1);
    }
}
