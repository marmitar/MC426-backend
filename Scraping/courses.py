"""
Get information from Unicamp courses from the 2021 catalog.
"""

from typing import TypedDict, Optional
import argparse
import bs4
from util import *


COURSES_URL = 'https://www.dac.unicamp.br/sistemas/catalogos/grad/catalogo2021/'


class Variant(TypedDict):
    name: str
    tree: list[list[str]]

class Course(TypedDict):
    code: str
    name: str
    variant: list[Variant]
    tree: Optional[list[list[str]]]


def get_course_url(course: Course) -> str:
    """
    Return the url for the desired course.
    """
    return COURSES_URL + 'cursos/' + str(course.get('code')) + 'g/sugestao.html'


def parse_course_text(text: str) -> Course:
    """
    From a source text, builds a Course instance.
    """
    code_name_sep = ' - '
    code, name = text.split(code_name_sep, 1)
    return Course(code=code, name=name)


def build_all_courses() -> list[Course]:
    """
    Build all courses instances from the index page without tree or variants.
    """
    index_url = COURSES_URL + 'index.html'
    soup = load_soup(index_url)
    course_class = 'rotulo-curso' # Part of the tag class.
    courses_tags = soup.find_all(True, class_=compile_regex(course_class))
    return [parse_course_text(tag.text) for tag in courses_tags]


def get_discipline_code(discipline_tag: bs4.element.Tag) -> str:
    """
    For a given discipine tag, split text between code and credits and return code.
    """
    clean_content = discipline_tag.text.split() # Remove whitespaces, tabs and similar.
    code = clean_content[0]

    # Check case where code has a whitespace (F 000).
    if len(code) == 1:
        code += ' ' + clean_content[1]

    return code


def build_period_disciplines(period_content_tag: bs4.element.Tag) -> list[str]:
    """
    Parse a period tag and create a list of disciplines codes.
    """
    disciplines_href = 'disc' # Part of the href value for discipline tags.
    disciplines_tags = period_content_tag.find_all(True, href=compile_regex(disciplines_href))
    return [get_discipline_code(tag) for tag in disciplines_tags]


def add_course_tree_or_variant(course: Course):
    """
    For a given course, add the tree or variant field using its html page.
    """
    url = get_course_url(course)
    soup = load_soup(url)
    period_text = 'semestre'
    periods_title_tags = soup.find_all('h3', string=compile_regex(period_text))
    periods_content_tags = [tag.next_sibling.next_sibling for tag in periods_title_tags] # First sibling is just a line break.
    tree = [build_period_disciplines(tag) for tag in periods_content_tags]
    course['tree'] = tree


def get_all_courses() -> list[Course]:
    """
    Build all courses and add tree or variants.
    """
    courses = build_all_courses()

    for course in courses:
        add_course_tree_or_variant(course)

    return courses


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('DIRECTORY', action='store', nargs=1, type=str,
        help='directory to save output'
    )

    args = parser.parse_args()

    for course in get_all_courses():
        dump_content_as_json(course, f"{args.DIRECTORY[0]}/{course['code']}.json")


if __name__ == '__main__':
    main()
