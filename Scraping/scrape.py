import re
import requests
import json
import argparse
import bs4

DISCIPLINES_URL = 'https://www.dac.unicamp.br/sistemas/catalogos/grad/catalogo2021/disciplinas/'


def is_discipline_code(code: str) -> bool:
    """Checks if code has format of discipline code."""
    return len(code) < 8


def get_disciplines_url(initials: str) -> str:
    return DISCIPLINES_URL + initials.lower() + '.html'


def get_all_disciplines_initials() -> list[str]:
    soup = load_soup(DISCIPLINES_URL + 'index.html')
    disciplines_div_class = 'disc' # Part of the div class.
    initials_div = soup.find(class_=re.compile(disciplines_div_class))
    return [initials.text.replace(' ', '_') for initials in initials_div.find_all('div')]


def load_soup(url: str) -> bs4.BeautifulSoup:
    return bs4.BeautifulSoup(requests.get(url).content, 'html.parser')


def get_disciplines(initials: str) -> bs4.element.ResultSet:
    url = get_disciplines_url(initials)
    soup = load_soup(url)
    disciplines_div_class = 'row' # Div class that identify a discipline at the page html.
    return soup.find_all(class_=disciplines_div_class)


def parse_requirements(raw: str) -> list[list[str]]:
    or_string = ' ou '
    and_string = '+'
    requirements = [group.split(and_string) for group in raw.split(or_string)]
    return requirements if is_discipline_code(requirements[0][0]) else None


def parse_disciplines(disciplines: bs4.element.ResultSet) -> dict:
    """Parse a div with correct class from disciplines source."""
    disciplines_dict = list()
    disciplines_id = 'disc' # Part of the id from the tag with code and name.
    code_name_sep = ' - ' # Discipline code and name separator.
    requirements_text = 'requisitos' # Part of the text in the requirements tag.

    for discipline in disciplines:
        try:
            # Discipline code and name:
            code_name_tag = discipline.find(id=re.compile(disciplines_id))
            code, name = code_name_tag.text.split(code_name_sep, 1)

            # Discipine requirements:
            requirements_tag = discipline.find(re.compile('.*'), string=re.compile(requirements_text))
            requirements = requirements_tag.next_sibling.next_sibling.text # First sibling is just a line break.

            # Save info:
            disciplines_dict.append({
                'code': code,
                'name': name,
                'req': parse_requirements(requirements)
            })

        except AttributeError:
            continue

    return disciplines_dict


def get_and_save_disciplines_data(initials: str, directory: str):
    disciplines = get_disciplines(initials)
    disciplines_dict = parse_disciplines(disciplines)
    with open(f'{directory}/{initials.upper()}.json', 'w') as file:
        json.dump(disciplines_dict, file, indent=4, ensure_ascii=False)


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
