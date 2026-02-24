// load in our helpers module
const helpers = require('./helpers.js');

/**
 * In this config, values are created with functions that are given a props object with dynamic values.
 * For example, props.__dirname will be the directory this file is in.
 * This allows us to easily use relative paths in the config file.
 * 
 * The helpers module is also available within these config functions for transforming values.
 */
module.exports = {

    /**
     * The file extension for the generated files, will be passed as prop.file_extension in config functions.
     * For example: ".js" for JavaScript, ".cs" for C#, etc.
     */
    output_file_extension: ".as",

    /**
     * Make the helpers module available to templates.
     */
    helpers: helpers,
    
    // File paths and directories for templates and helpers
    // Note: do not add trailing slashes to directory paths!

    /**
     * Directory where generated class & model files will be placed.
     * Used by the model builder, and the core generator.
     * Note: __dirname is the directory this config file is in.
     */
    build_dir: `${__dirname}/../../build`,

    /**
     * Top-level directory where your model files will be placed.
     * Should be inside the build_dir.
     * Used by the model builder.
     * Note: __dirname is the directory this config file is in.
     */
    models_dir: `${__dirname}/../../build/io/newgrounds/models`,
   
    /**
     * Directory where your template files and are located.
     * Used by the model builder.
     * Note: __dirname is the directory this config file is in.
     */
    template_dir: `${__dirname}/../templates`,
    
    /**
     * Directory where your partial template files and are located.
     * Used by the model builder.
     * (this should always be inside the main template_dir)
     */
    partials_dir: `${__dirname}/../templates/partials`,

    /**
     * The following config values are wrapped in functions, allowing you to use dynamic
     * values and helper methods to format your paths and names as needed.
     * All of the above config properties will be available inside of a 'config' object in templates.
     * 
     * Some functions will also have aditional prameters, such as objectName, componentScope, etc.
     * 
     * For example, you can access the build_dir property like this:
     *   - config.build_dir
     * 
     * Or, if you need to use a helper method to format a name, you can do so like this:
     *   - helpers.convertToSnakeCase(objectName)
     */

    /**
     * Template files for the model builder.  These are EJS templates.
     */
    template_files: {

		/**
         * Templates for your core objects
         * 
         * Parameters:
         *  - config: This full config object
         */
        objects: (config) => {
            return `${config.template_dir}/object.ejs`;
        },

		/**
         * Templates for component objects
         * 
         * Parameters:
         *  - config: This full config object
         */
        components: (config) => {
            return `${config.template_dir}/component.ejs`;
        },

		/**
         * Templates for component results objects
         * 
         * Parameters:
         *  - config: This full config object
         */
        results: (config) => {
            return `${config.template_dir}/result.ejs`;
        },

		/**
         * Template for an object factory class (used to create instances using object and component names)
         * Note: If you don't need an object factory class, you can remove this line.
         * 
         * Parameters:
         *  - config: This full config object
         */
        object_factory: (config) => {
            return `${config.template_dir}/object_factory.ejs`;
        }
    },


    model_files: {

		/**
         * Path to where your object models will be saved
         * 
         * Parameters:
         *  - config: This full config object
         *  - objectName: The name of the object, e.g. "User", "ScoreBoard", etc.
         */
        objects: (config, objectName) => {
            const className = helpers.getClassName(objectName);
            return `${config.models_dir}/objects/${className}${config.output_file_extension}`;
        },

		/**
         * Path to where your component models will be saved
         * 
         * Parameters:
         *  - config: This full config object
         *  - componentScope: The scope of the component
         *  - componentMethod: The method of the component
         */
        components: (config, componentScope, componentMethod) => {
            return `${config.models_dir}/components/${componentScope}/${componentMethod}${config.output_file_extension}`;
        },

		/**
         * Path to where your component results models will be saved
         * 
         * Parameters:
         *  - config: This full config object
         *  - componentScope: The scope of the component
         *  - componentMethod: The method of the component
         */
        results: (config, componentScope, componentMethod) => {
            return `${config.models_dir}/results/${componentScope}/${componentMethod}Result${config.output_file_extension}`;
        },

		/**
         * Path to where the object factory file will be saved
         * 
         * Parameters:
         *  - config: This full config object
         */
        object_factory: (config) => {
            return `${config.models_dir}/objects/ObjectFactory${config.output_file_extension}`;
        }
    },

    /**
     * CORE FILE GENERATION (OPTIONAL)
     * -------------------------------
     *
     * These files make up the "foundation" of the generated library.
     *
     * Unlike object and component models (which are auto-generated),
     * core files are real, hand-written code that everything else
     * depends on.
     *
     * Examples of core files:
     *   - The main NGIO class you interact with
     *   - Base classes that all generated models extend from
     *   - Shared networking, serialization, and formatting logic
     *
     * You normally generate these files ONCE when starting a new project.
     * After that, you may edit them by hand.
     *
     * Because these files are meant to be customized, they are NOT
     * automatically overwritten unless you explicitly allow it.
     *
     * If you already have your own implementation, you can disable
     * this section entirely.
     * 
     * These will generate as pseudo-code skeletons that you can
     * translate into your target language.
     */
    core_files: {

        /**
         * Enable or disable core file generation.
         *
         * - true  → Core files will be generated if missing
         * - false → Core files will be ignored completely
         */
        enabled: true,

        /**
         * Controls what happens if a core file already exists.
         *
         * - false (recommended):
         *     Existing files are left alone.
         *     This protects your custom changes.
         *
         * - true:
         *     Existing files will be replaced.
         *     Use with caution.
         */
        overwrite: false,

        /**
         * Individual core files to generate.
         *
         * You may rename or relocate these files to match
         * the conventions of your target language or framework.
         *
         * If a file path is removed, that file will not be generated.
         * 
         * Each function receives the config object as a parameter.
         */
        files: {

            // A guide explaining how to implement and customize the generated library
            // If you don't need this, you can remove this line.
            ImplementationGuide: (config) => {
                return `${config.build_dir}/IMPLEMENTATION_GUIDE.txt`;
            },

            // The main wrapper class your developers will use to access the API
            NGIO: (config) => {
                return `${config.build_dir}/NGIO${config.output_file_extension}`;
            },

            // Core helper classes and utilities (networking, config, etc)
            Core: (config) => {
                return `${config.build_dir}/io/newgrounds/Core${config.output_file_extension}`;
            },

            // Error handling classes
            Errors: (config) => {
                return `${config.build_dir}/io/newgrounds/Errors${config.output_file_extension}`;
            },

            // Application state management
            AppState: (config) => {
                return `${config.build_dir}/io/newgrounds/AppState${config.output_file_extension}`;
            },

            // Session status constants
            SessionStatus: (config) => {
                return `${config.build_dir}/io/newgrounds/SessionStatus${config.output_file_extension}`;
            },

            // Base class for all generated object models
            BaseObject: (config) => {
                return `${config.build_dir}/io/newgrounds/BaseObject${config.output_file_extension}`;
            },

            // Base class for all generated component models
            BaseComponent: (config) => {
                return `${config.build_dir}/io/newgrounds/BaseComponent${config.output_file_extension}`;
            },

            // Base class for all generated result models
            BaseResult: (config) => {
                return `${config.build_dir}/io/newgrounds/BaseResult${config.output_file_extension}`;
            }
        }
    }
};