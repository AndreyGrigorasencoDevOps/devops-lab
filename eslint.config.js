// ESLint v10 flat config for Node.js / Express project

const js = require("@eslint/js");
const globals = require("globals");

module.exports = [
  // 1) Global ignores
  {
    ignores: ["node_modules/**", "dist/**", "coverage/**"],
  },

  // 2) Base recommended rules from ESLint
  js.configs.recommended,

  // 3) Global configuration for all JS files
  {
    files: ["**/*.js"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "commonjs",
      globals: {
        ...globals.node, // Enable Node.js globals (process, __dirname, etc.)
      },
    },
    rules: {
      // Strict variable handling
      "no-unused-vars": ["error", { args: "after-used", vars: "all" }],

      // Code correctness & safety
      "eqeqeq": "error",
      "curly": "error",
      "no-empty": "error",

      // Disallow console in production code
      "no-console": "error",
    },
  },

  // 4) Override for Express middleware
  {
    files: ["src/middlewares/**/*.js"],
    rules: {
      // Allow unused parameters prefixed with _
      "no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],
    },
  },

  // 5) Override for Express controllers & routes
  {
    files: ["src/controllers/**/*.js", "src/routes/**/*.js"],
    rules: {
      "no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],
    },
  },
];