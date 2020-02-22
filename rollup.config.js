import resolve from 'rollup-plugin-node-resolve';
import { terser } from 'rollup-plugin-terser';
import analyze from 'rollup-plugin-analyzer';
import copy from 'rollup-plugin-copy';

const production = process.env.BUILD === 'production';

export default [
    {
        input: [
            '@teipublisher/pb-components/src/pb-components-bundle.js',
            '@teipublisher/pb-components/src/pb-facsimile.js',
            '@teipublisher/pb-components/src/pb-leaflet-map.js',
            './components/pb-edit-app.js'
        ],
        output: {
            dir: 'resources/scripts',
            format: 'es',
            sourcemap: true
        },
        plugins: [
            resolve(),
            production && terser(),
            copy({
                targets: [
                    {
                        src: './node_modules/leaflet/dist/leaflet.css',
                        dest: './resources/css/vendor'
                    },
                    {
                        src: './node_modules/leaflet/dist/images/*',
                        dest: './resources/images/leaflet'
                    },
                    {
                        src: './node_modules/openseadragon/build/openseadragon/images/*',
                        dest: './resources/images/openseadragon'
                    }
                ]
            }),
            analyze({
                summaryOnly: true
            })
        ]
    },
    {
        input: '@teipublisher/pb-components/src/pb-components-all.js',
        output: {
            file: 'resources/scripts/pb-components-all.js',
            format: 'iife',
            sourcemap: true
        },
        plugins: [
            resolve(),
            production && terser(),
            analyze({
                summaryOnly: true
            })
        ]
    }
]