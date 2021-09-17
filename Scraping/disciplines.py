"""
Get information for Unicamp disciplines from the 2021 catalog.
"""

from __future__ import annotations
import re
from typing import Any, TypedDict, Optional
import argparse
import bs4
from util import *


DISCIPLINES_URL = 'https://www.dac.unicamp.br/sistemas/catalogos/grad/catalogo2021/disciplinas/'


class Discipline(TypedDict):
    code: str
    name: str
    reqs: Optional[list[list[Requirement]]]


class Requirement(TypedDict):
    code: str
    partial: Optional[bool]
    special: Optional[bool]


def is_discipline_code(code: str) -> bool:
    """Checks if code has format of discipline code."""
    return len(code) == 5


def get_disciplines_url(initials: str) -> str:
    """Return the url for the desired initials."""
    return DISCIPLINES_URL + initials.lower() + '.html'


def get_all_disciplines_initials() -> list[str]:
    """Return a list of initials from the catalog."""
    soup = load_soup(DISCIPLINES_URL + 'index.html')
    disciplines_div_class = 'disc' # Part of the div class.
    initials_div = soup.find(class_=re.compile(disciplines_div_class))
    return [initials.text.replace(' ', '_') for initials in initials_div.find_all('div')]


def get_disciplines(initials: str) -> bs4.element.ResultSet:
    """Get disciplines with desired initials."""
    url = get_disciplines_url(initials)
    soup = load_soup(url)
    disciplines_div_class = 'row' # Div class that identify a discipline at the page html.
    return soup.find_all(class_=disciplines_div_class)


def create_requirement(raw: str) -> Requirement:
    """Create a requirement for the first time, with its code and 'partial' flag."""
    code: str
    partial: bool

    # Checks for common discipline code:
    if is_discipline_code(raw):
        code = raw
        partial = False

    # Checks for string of type '*AA000':
    elif is_discipline_code(raw[1:]) and raw[0] == '*':
        code = raw[1:]
        partial = True

    else:
        return None

    return Requirement(code=code, partial=partial)


def parse_requirements(raw: str) -> list[list[Requirement]]:
    """Parse requirements for a discipline."""
    or_string = ' ou '
    and_string = '+'
    groups = raw.split(or_string)

    requirements = list()

    for group in groups:
        group_reqs = [create_requirement(raw) for raw in group.split(and_string)]

        # Checks for non-valid requirements:
        if None in group_reqs:
            return None

        requirements.append(group_reqs)

    return requirements


def parse_disciplines(disciplines: bs4.element.ResultSet) -> list[Discipline]:
    """Parse a div with correct class from disciplines source."""
    disciplines_id = 'disc' # Part of the id from the tag with code and name.
    code_name_sep = ' - ' # Discipline code and name separator.
    requirements_text = 'requisitos' # Part of the text in the requirements tag.

    disciplines_list = list()
    for discipline in disciplines:
        try:
            discipline_dict = Discipline()

            # Discipline code and name:
            code_name_tag = discipline.find(id=re.compile(disciplines_id))
            code, name = code_name_tag.text.split(code_name_sep, 1)
            discipline_dict['code'] = code

            # Discipine requirements:
            requirements_tag = discipline.find(re.compile('.*'), string=re.compile(requirements_text))
            requirements_string = requirements_tag.next_sibling.next_sibling.text # First sibling is just a line break.
            discipline_dict['req'] = parse_requirements(requirements_string)

            # Save info:
            disciplines_list.append(discipline_dict)

        except AttributeError:
            continue

    return disciplines_list


def get_and_save_disciplines_data(initials: str, directory: str):
    """Save discipline data for desired initials as a json file."""
    disciplines = get_disciplines(initials)
    disciplines_dict = parse_disciplines(disciplines)
    dump_content_as_json(disciplines_dict, f'{directory}/{initials.upper()}.json')


def get_and_save_all_disciplines_data(directory: str):
    """Save all data as json files in a directory."""
    initial_list = get_all_disciplines_initials()
    for initials in initial_list:
        get_and_save_disciplines_data(initials, directory)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('DIRECTORY', action='store', nargs=1, type=str,
        help='directory to save output'
    )

    args = parser.parse_args()

    get_and_save_all_disciplines_data(args.DIRECTORY[0])


if __name__ == '__main__':
    main()
