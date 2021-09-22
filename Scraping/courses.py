"""
Get information from Unicamp courses from the 2021 catalog.
"""

from json import load
from typing import TypedDict, Optional
from util import *


COURSES_URL = 'https://www.dac.unicamp.br/sistemas/catalogos/grad/catalogo2021/cursos/'


class Course(TypedDict):
    code: int
    name: str
    tree: Optional[list[list[str]]]


def get_course_url(course: Course) -> str:
    """
    Return the url for the desired course.
    """
    return COURSES_URL + str(course.get('code')) + 'g/sugestao.html'


def parse_course_text(text: str) -> Course:
    """
    From a source text, builds a Course instance.
    """
    code_name_sep = ' - '
    code, name = text.split(code_name_sep, 1)
    return Course(code=int(code), name=name)


def get_all_courses() -> list[Course]:
    """
    Build all courses instances from the index page.
    """
    index_url = 'https://www.dac.unicamp.br/sistemas/catalogos/grad/catalogo2021/index.html'
    soup = load_soup(index_url)
    course_class = 'curso' # Part of the html component class.
    courses_components = soup.find_all('a', class_=compile_regex(course_class))
    return [parse_course_text(component.text) for component in courses_components]


def add_course_tree(course: Course):
    """
    For a given course, add the tree field using its html page.
    """
    url = get_course_url(course)
    soup = load_soup(url)
    period_text = 'semestre'
    periods_components = soup.find_all('h3', string=compile_regex(period_text))
    for period_component in periods_components:
        print(period_component)


def main():
    courses = get_all_courses()
    course = courses[0]
    add_course_tree(course)


if __name__ == '__main__':
    main()
