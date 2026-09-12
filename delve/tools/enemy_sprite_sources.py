"""Design source name and foot margin for authored enemy animation exports."""

SOURCES = [
    ('goblin', 6), ('kobold', 6), ('wolf', 4), ('viper', 4),
    ('spider', 4), ('boar', 4), ('giant-viper', 4),
    ('giant-monitor-lizard', 4), ('dire-wolf', 4),
    ('grizzly-bear', 4), ('giant-stag-beetle', 4),
]


def runtime_folder(kind):
    return kind.replace('-', '_') + '_base'
