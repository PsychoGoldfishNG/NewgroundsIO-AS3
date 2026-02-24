// Here are some sample helper methods you can use in your templates.
// You can add any methods here that can keep your templates clean and focused on rendering data.
// your templates will be able to access these methods using the `helper` object.

module.exports = {

    // If you use namespacing, or prefixes, you can use this to inject any namespacing you want.
    // for example, if you want to use the io.newgrounds.models.* namespace...
    baseNamespace: "io.newgrounds.models",

    /**
     * Maps model names to their preferred class names.
     * Some API model names conflict with native classes (e.g., "Error")
     * so we rename them to avoid ambiguity.
     */
    classNameMap: {
        "Error": "NgioError"
    },

    /**
     * Gets the preferred class name for a model, applying any mappings.
     * @param {string} modelName The original model name from the API.
     * @returns {string} The mapped class name (e.g., "Error" becomes "NgioError").
     */
    getClassName(modelName) {
        if (!modelName) return "";
        return this.classNameMap[modelName] || modelName;
    },

    /**
     * Gets the original API name for a model (reverse mapping).
     * @param {string} className The class name used in code.
     * @returns {string} The original API model name.
     */
    getOriginalName(className) {
        if (!className) return "";
        // Reverse lookup in the map
        for (const [original, mapped] of Object.entries(this.classNameMap)) {
            if (mapped === className) return original;
        }
        return className;
    },

    /**
     * Converts the first character of a string to uppercase.
     * @param {string} str The string to convert.
     * @returns {string} The converted string.
     */
    firstCharToUpper(str) {
        if (!str) return "";
        return str.charAt(0).toUpperCase() + str.slice(1);
    },

    /**
     * Converts a string from kebab-case, snake_case, or camelCase to an array of words in lowercase.
     * @param {string} str The string to convert.
     * @returns {string[]} An array of words in lowercase.
     */
    convertToWords(str) {
        if (!str) return "";
        let words = str.replace(/[-_]/g, " "); // replace - and _ with spaces
        words = words.replace(/([a-z])ID$/i, '$1 id'); // replace trailing ID with id
        words = words.replace(/([a-z])([A-Z])/g, '$1 $2'); // add space before capital letters
        // eliminate any double spaces
        words = words.replace(/\s+/g, ' ');
        // send an array of words back in all lowercase
        return words.toLowerCase().split(" ").filter(w => w);
    },

    /**
     * Converts a string to camelCase.
     * @param {string} str The string to convert.
     * @returns {string} The converted string in camelCase.
     */
    convertToCamelCase(str) {
        if (!str) return "";
        const words = this.convertToWords(str);
        return words.map((word, index) => {
            if (index === 0) return word;
            return this.firstCharToUpper(word);
        }).join("");
    },

    /**
     * Converts a string to PascalCase.
     * @param {string} str The string to convert.
     * @returns {string} The converted string in PascalCase.
     */
    convertToPascalCase(str) {
        if (!str) return "";
        const words = this.convertToWords(str);
        return words.map(word => this.firstCharToUpper(word)).join("");
    },

    /**
     * Converts a string to snake_case.
     * @param {string} str The string to convert.
     * @returns {string} The converted string in snake_case.
     */
    convertToSnakeCase(str) {
        if (!str) return "";
        const words = this.convertToWords(str);
        return words.join("_");
    },

    /**
     * Converts a string to SCREAMING_SNAKE_CASE.
     * @param {string} str The string to convert.
     * @returns {string} The converted string in SCREAMING_SNAKE_CASE.
     */
    convertToScreamingSnakeCase(str) {
        if (!str) return "";
        const words = this.convertToWords(str);
        return words.join("_").toUpperCase();
    },

    /**
     * Converts a string to kebab-case.
     * @param {string} str The string to convert.
     * @returns {string} The converted string in kebab-case.
     */
    convertToKebabCase(str) {
        if (!str) return "";
        const words = this.convertToWords(str);
        return words.join("-");
    },

    /**
     * Formats a multiline comment with the given indentation.
     * @param {string} comment The comment text to format. Each line should be separated by a newline character.
     * @param {string} indent The indentation string to prepend to each line of the comment.
     * @param {boolean} indentFirstLine Whether to indent the opening /** line. Default is false.
     * @returns {string} The formatted multiline comment.
     */
    formatMultilineComment(comment, indent = "", indentFirstLine = false) {
        if (!comment) return "";
        
        const lines = comment.split("\n");

        let comments = indentFirstLine
            ? `${indent}/**\n${lines.map(line => `${indent} * ${line}`).join("\n")}\n${indent} */`
            : `/**\n${lines.map(line => `${indent} * ${line}`).join("\n")}\n${indent} */`;

        // documents prefix object names with #
        // you can use this to inject any namespacing you want.
        // for example, if you want to use the newgroundsIO.models.objects namespace...
        comments = comments.replace(/#(\w+)/g, `${this.baseNamespace}.objects.$1`);
        return comments;
    },

    /**
     * Gets the native type for a given object definition
     * @param {object} obj The object definition to get the type for.
     * @returns {string} The native type.
     */
    getDataType(obj) {

        // this object can be a typed array
        if (obj.array) {
            // some objects can be a typed array or a flat value or object
            if (obj.type || obj.object) {
                return "*"; // Any type
            } else {
                return "Array";
            }
        }

        // We don't generate an actual Result object, as every component
        // has a specific result object.
        // In this example, we're assuming you have a parent BaseResult class
        // that all results extend.
        // Depending on your language, you may want to change this to return a mixed type.
        if (obj.object === "Result") {
            return `${this.baseNamespace}.BaseResult`;
        }

        // if this has an object type, it will be one of our generated object classes
        // update this to reflect any namespacing you use in your project.
        // for example, if you want to use the newgroundsIO.models.objects namespace...
        if (obj.object) {
            const className = this.getClassName(obj.object);
            return `${this.baseNamespace}.objects.${className}`;
        }

        // if we have none of the above, and no type, this is a void type
        if (!obj.type) return "Void";

        // if we have a type property, this will be a native type. Send the proper type back!
        switch (obj.type) {
            case "array":
                return "Array"; // or List, depending on your language
            case "object":
                return "Object"; // or Map, Dictionary, Hash, etc. depending on your language
            case "string":
                return "String";
            case "int":
                return "Number"; // or Integer, depending on your language
            case "float":
                return "Number"; // or Float/Double, depending on your language
            case "boolean":
                return "Boolean";
            case "mixed":
                return "*"; // Any type
        }

    },

    /**
     * Gets the appropriate default value for a property
     * @param {object} property The property definition
     * @returns {string} The default value as a string
     */
    getDefaultValue(property) {
        // If an explicit default is provided, use it
        if (property.default !== undefined) {
            return JSON.stringify(property.default);
        }

        // Handle primitives that can't be null
        const dataType = this.getDataType(property);
        
        // Number types may need to default to NaN (not-a-number) instead of null
        if (dataType === "Number") {
            return "NaN";
        }
        
        // Boolean types may need to default to false instead of null
        if (dataType === "Boolean") {
            return "false";
        }
        
        // Everything else can be null (objects, strings, arrays, etc.)
        return "null";
    }
}
