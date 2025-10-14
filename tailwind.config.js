/**
 * Tailwind CSS Configuration - Enterprise Grade
 * Sophisticated configuration with advanced theming, performance optimizations,
 * and comprehensive design system integration
 */

// Color System - Centralized Design Tokens
const colorPalette = {
  // Primary Brand Colors
  spirit: {
    primary: 'var(--color-spirit-primary, #6366f1)',
    secondary: 'var(--color-spirit-secondary, #8b5cf6)',
    accent: 'var(--color-spirit-accent, #ec4899)',
    light: 'var(--color-spirit-light, #f8fafc)',
    dark: 'var(--color-spirit-dark, #0f172a)',
  },

  // Nature-inspired Colors
  nature: {
    green: {
      50: 'var(--color-nature-green-50, #f0fdf4)',
      100: 'var(--color-nature-green-100, #dcfce7)',
      500: 'var(--color-nature-green-500, #22c55e)',
      900: 'var(--color-nature-green-900, #14532d)',
    },
    brown: {
      50: 'var(--color-nature-brown-50, #fef7ed)',
      100: 'var(--color-nature-brown-100, #fed7aa)',
      500: 'var(--color-nature-brown-500, #a3540f)',
      900: 'var(--color-nature-brown-900, #422006)',
    },
  },

  // Semantic Colors
  semantic: {
    success: 'var(--color-semantic-success, #10b981)',
    warning: 'var(--color-semantic-warning, #f59e0b)',
    error: 'var(--color-semantic-error, #ef4444)',
    info: 'var(--color-semantic-info, #3b82f6)',
  },

  // Neutral Colors
  neutral: {
    50: 'var(--color-neutral-50, #fafafa)',
    100: 'var(--color-neutral-100, #f5f5f5)',
    200: 'var(--color-neutral-200, #e5e5e5)',
    300: 'var(--color-neutral-300, #d4d4d4)',
    400: 'var(--color-neutral-400, #a3a3a3)',
    500: 'var(--color-neutral-500, #737373)',
    600: 'var(--color-neutral-600, #525252)',
    700: 'var(--color-neutral-700, #404040)',
    800: 'var(--color-neutral-800, #262626)',
    900: 'var(--color-neutral-900, #171717)',
  },
};

// Animation System - Performance Optimized
const animationConfig = {
  keyframes: {
    'spirit-pulse': {
      '0%, 100%': {
        opacity: '1',
        transform: 'scale(1)',
      },
      '50%': {
        opacity: '.8',
        transform: 'scale(1.05)',
      },
    },
    'fade-in': {
      '0%': {
        opacity: '0',
        transform: 'translateY(10px)',
      },
      '100%': {
        opacity: '1',
        transform: 'translateY(0)',
      },
    },
    'slide-in': {
      '0%': {
        opacity: '0',
        transform: 'translateX(-100%)',
      },
      '100%': {
        opacity: '1',
        transform: 'translateX(0)',
      },
    },
  },
  animation: {
    'spirit-pulse': 'spirit-pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite',
    'fade-in': 'fade-in 0.5s ease-out',
    'slide-in': 'slide-in 0.3s ease-out',
    'bounce-gentle': 'bounce 1s infinite',
  },
};

// Typography Scale - Fluid Typography System
const typographyConfig = {
  fontFamily: {
    sans: [
      'Inter',
      'system-ui',
      '-apple-system',
      'BlinkMacSystemFont',
      'Segoe UI',
      'Roboto',
      'Helvetica Neue',
      'Arial',
      'sans-serif',
    ],
    serif: [
      'Georgia',
      'Cambria',
      'Times New Roman',
      'Times',
      'serif',
    ],
    mono: [
      'JetBrains Mono',
      'Menlo',
      'Monaco',
      'Consolas',
      'Liberation Mono',
      'Courier New',
      'monospace',
    ],
  },
  fontSize: {
    'xs': ['0.75rem', { lineHeight: '1rem' }],
    'sm': ['0.875rem', { lineHeight: '1.25rem' }],
    'base': ['1rem', { lineHeight: '1.5rem' }],
    'lg': ['1.125rem', { lineHeight: '1.75rem' }],
    'xl': ['1.25rem', { lineHeight: '1.75rem' }],
    '2xl': ['1.5rem', { lineHeight: '2rem' }],
    '3xl': ['1.875rem', { lineHeight: '2.25rem' }],
    '4xl': ['2.25rem', { lineHeight: '2.5rem' }],
    '5xl': ['3rem', { lineHeight: '1' }],
    '6xl': ['3.75rem', { lineHeight: '1' }],
  },
};

// Spacing Scale - Consistent and Logical
const spacingConfig = {
  spacing: {
    '18': '4.5rem',
    '88': '22rem',
    '128': '32rem',
    '144': '36rem',
  },
};

// Shadow System - Layered and Sophisticated
const shadowConfig = {
  boxShadow: {
    'spirit': 'var(--spirit-glow, 0 0 20px rgba(99, 102, 241, 0.15))',
    'spirit-lg': 'var(--spirit-glow-lg, 0 10px 40px rgba(99, 102, 241, 0.1))',
    'nature': '0 4px 14px 0 rgba(34, 197, 94, 0.1)',
    'nature-lg': '0 10px 40px 0 rgba(34, 197, 94, 0.15)',
    'inner-light': 'inset 0 2px 4px 0 rgba(0, 0, 0, 0.05)',
    'dropdown': '0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)',
  },
};

// Border Radius Scale
const borderRadiusConfig = {
  borderRadius: {
    'xl': '0.75rem',
    '2xl': '1rem',
    '3xl': '1.5rem',
    '4xl': '2rem',
  },
};

// Performance Optimizations
const performanceConfig = {
  // Enable JIT mode for better performance
  mode: 'jit',

  // Content patterns for purging - optimized for Rails
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/javascript/**/*.jsx',
    './app/javascript/**/*.ts',
    './app/javascript/**/*.tsx',
    './app/components/**/*.{js,jsx,ts,tsx}',
  ],

  // Enable experimental features for better performance
  experimental: {
    optimizeUniversalDefaults: true,
  },

  // Core plugins only for better performance
  corePlugins: {
    preflight: true,
    container: true,
    accessibility: true,
    pointerEvents: true,
    position: true,
    inset: true,
    isolation: true,
    zIndex: true,
    order: true,
    col: true,
    row: true,
    gridColumn: true,
    gridRow: true,
    float: true,
    clear: true,
    objectFit: true,
    objectPosition: true,
    overflow: true,
    overscrollBehavior: true,
    scrollBehavior: true,
    scrollMargin: true,
    scrollPadding: true,
    listStyleType: true,
    listStylePosition: true,
    appearance: true,
    columns: true,
    breakBefore: true,
    breakInside: true,
    breakAfter: true,
    gridAutoColumns: true,
    gridAutoFlow: true,
    gridAutoRows: true,
    gridTemplateColumns: true,
    gridTemplateRows: true,
    flexDirection: true,
    flexWrap: true,
    placeContent: true,
    placeItems: true,
    alignContent: true,
    alignItems: true,
    justifyContent: true,
    justifyItems: true,
    gap: true,
    space: true,
    divideWidth: true,
    divideColor: true,
    divideStyle: true,
    divideOpacity: true,
    placeSelf: true,
    alignSelf: true,
    justifySelf: true,
    resize: true,
    snapAlign: true,
    snapStop: true,
    snapType: true,
    touchAction: true,
    userSelect: true,
    willChange: true,
    cursor: true,
    caretColor: true,
    accentColor: true,
    scrollSnapAlign: true,
    scrollSnapStop: true,
    scrollSnapType: true,
    borderCollapse: true,
    borderSpacing: true,
    tableLayout: true,
    transitionBehavior: true,
    display: true,
    aspectRatio: true,
    size: true,
    animation: true,
    transform: true,
    transformOrigin: true,
    scale: true,
    rotate: true,
    translate: true,
    skew: true,
    transformStyle: true,
    perspective: true,
    perspectiveOrigin: true,
    backdropBlur: true,
    backdropBrightness: true,
    backdropContrast: true,
    backdropGrayscale: true,
    backdropHueRotate: true,
    backdropInvert: true,
    backdropOpacity: true,
    backdropSaturate: true,
    backdropSepia: true,
    backgroundAttachment: true,
    backgroundBlendMode: true,
    backgroundClip: true,
    backgroundColor: true,
    backgroundImage: true,
    backgroundOrigin: true,
    backgroundPosition: true,
    backgroundRepeat: true,
    backgroundSize: true,
    backgroundGradient: true,
    gradientColorStops: true,
    borderRadius: true,
    borderWidth: true,
    borderColor: true,
    borderStyle: true,
    borderOpacity: true,
    borderImage: true,
    borderImageSource: true,
    borderImageSlice: true,
    borderImageWidth: true,
    borderImageOutset: true,
    borderImageRepeat: true,
    outlineWidth: true,
    outlineColor: true,
    outlineStyle: true,
    outlineOffset: true,
    outlineOpacity: true,
    boxShadow: true,
    boxShadowColor: true,
    opacity: true,
    mixBlendMode: true,
    backgroundBlendMode: true,
    filter: true,
    blur: true,
    brightness: true,
    contrast: true,
    dropShadow: true,
    grayscale: true,
    hueRotate: true,
    invert: true,
    saturate: true,
    sepia: true,
    transitionDelay: true,
    transitionDuration: true,
    transitionProperty: true,
    transitionTimingFunction: true,
    content: true,
    fontFamily: true,
    fontSize: true,
    fontSmoothing: true,
    fontStyle: true,
    fontWeight: true,
    fontVariantNumeric: true,
    letterSpacing: true,
    lineClamp: true,
    lineHeight: true,
    textAlign: true,
    textColor: true,
    textDecoration: true,
    textDecorationColor: true,
    textDecorationStyle: true,
    textDecorationThickness: true,
    textUnderlineOffset: true,
    textTransform: true,
    textOverflow: true,
    textIndent: true,
    verticalAlign: true,
    whitespace: true,
    wordBreak: true,
    hyphenateCharacter: true,
    textShadow: true,
    writingMode: true,
    direction: true,
    unicodeBidi: true,
  },
};

// Advanced Plugin Configuration
const pluginConfig = {
  plugins: [
    // Custom plugin for advanced utilities
    function({ addUtilities, addComponents, theme }) {
      // Advanced gradient utilities
      const gradients = {
        '.bg-gradient-spirit': {
          background: 'linear-gradient(135deg, var(--color-spirit-primary), var(--color-spirit-secondary))',
        },
        '.bg-gradient-nature': {
          background: 'linear-gradient(135deg, var(--color-nature-green-500), var(--color-nature-brown-500))',
        },
        '.text-gradient': {
          background: 'linear-gradient(135deg, var(--color-spirit-primary), var(--color-spirit-accent))',
          '-webkit-background-clip': 'text',
          '-webkit-text-fill-color': 'transparent',
          'background-clip': 'text',
        },
      };

      // Advanced component utilities
      const components = {
        '.btn-spirit': {
          background: 'linear-gradient(135deg, var(--color-spirit-primary), var(--color-spirit-secondary))',
          color: 'white',
          padding: '0.5rem 1rem',
          borderRadius: theme('borderRadius.lg'),
          fontWeight: '500',
          transition: 'all 0.2s ease-in-out',
          boxShadow: theme('boxShadow.spirit'),
          '&:hover': {
            transform: 'translateY(-1px)',
            boxShadow: theme('boxShadow.spirit-lg'),
          },
        },
        '.card-elevated': {
          background: 'white',
          borderRadius: theme('borderRadius.xl'),
          boxShadow: theme('boxShadow.spirit'),
          transition: 'all 0.3s ease-in-out',
          '&:hover': {
            transform: 'translateY(-4px)',
            boxShadow: theme('boxShadow.spirit-lg'),
          },
        },
      };

      addUtilities(gradients);
      addComponents(components);
    },
  ],
};

// Main Configuration Export
module.exports = {
  ...performanceConfig,

  theme: {
    extend: {
      // Color system integration
      colors: {
        ...colorPalette.spirit,
        ...colorPalette.nature,
        ...colorPalette.nature.green,
        ...colorPalette.nature.brown,
        ...colorPalette.semantic,
        ...colorPalette.neutral,
      },

      // Typography system
      fontFamily: typographyConfig.fontFamily,
      fontSize: typographyConfig.fontSize,

      // Spacing system
      ...spacingConfig,

      // Shadow system
      boxShadow: shadowConfig.boxShadow,

      // Border radius system
      ...borderRadiusConfig,

      // Animation system
      keyframes: animationConfig.keyframes,
      animation: animationConfig.animation,

      // Advanced screen breakpoints
      screens: {
        'xs': '475px',
        '3xl': '1600px',
        '4xl': '1920px',
      },

      // Container configuration
      container: {
        center: true,
        padding: {
          DEFAULT: '1rem',
          sm: '2rem',
          lg: '4rem',
          xl: '5rem',
          '2xl': '6rem',
        },
      },

      // Transition configuration
      transitionTimingFunction: {
        'bounce-gentle': 'cubic-bezier(0.68, -0.55, 0.265, 1.55)',
      },
    },
  },

  ...pluginConfig,

  // Future-proof configuration
  future: {
    hoverOnlyWhenSupported: true,
  },
};