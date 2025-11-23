<?php
$entityDir = __DIR__ . '/src/Entity';
$files = scandir($entityDir);

foreach ($files as $file) {
    if (pathinfo($file, PATHINFO_EXTENSION) === 'php') {
        $path = "$entityDir/$file";
        $content = file_get_contents($path);

        // Ajoute le use ApiResource s'il n'existe pas
        if (strpos($content, 'ApiPlatform\Metadata\ApiResource') === false) {
            $content = preg_replace(
                '/namespace App\\\\Entity;/',
                "namespace App\Entity;\n\nuse ApiPlatform\Metadata\ApiResource;",
                $content,
                1
            );
        }

        // Ajoute #[ApiResource] avant class si absent
        if (strpos($content, '#[ApiResource]') === false) {
            $content = preg_replace(
                '/class (\w+)/',
                "#[ApiResource]\nclass $1",
                $content,
                1
            );
        }

        file_put_contents($path, $content);
        echo "Mis à jour : $file\n";
    }
}
