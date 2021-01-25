<?php

declare(strict_types=1);

use Behat\Behat\Context\Context;

class VPNMinuteContext implements Context
{
    private $expected_output;

    /**
     * @When /^the main application is run$/
     */
    public function theApplicationIsRun()
    {
        ob_start();

        include __DIR__.'/../../main.php';

        $output = ob_get_contents();

        if (strstr($this->expected_output, $output)) {
            throw new \Exception("Cannot assert that “ $output ” contains “ $this->expected_output ”");
        }
    }

    /**
     * @Given /^(?:he|I) expect to see \"?([^"]+)\"?$/
     */
    public function iExpectToSee(string $output)
    {
        $this->expected_output = $output;
    }
}
